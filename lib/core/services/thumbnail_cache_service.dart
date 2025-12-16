// ============================================
// PERFORMANCE OPTIMIZATION SYSTEM
// ============================================

// 1. Thumbnail Cache Service with Multi-tier Strategy
// services/thumbnail_cache_service.dart

import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:files_manager/core/models/file_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ThumbnailCacheService {
  static final ThumbnailCacheService _instance = ThumbnailCacheService._();
  factory ThumbnailCacheService() => _instance;
  ThumbnailCacheService._();

  // Memory cache (LRU-style with fixed size)
  final Map<String, Uint8List> _memoryCache = {};
  final List<String> _lruKeys = [];
  static const int _maxMemoryCacheSize = 200;

  // Disk cache directory
  Directory? _cacheDir;

  // Isolate pool for thumbnail generation
  final List<SendPort?> _isolatePorts = List.filled(4, null);
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Setup disk cache
    final appDir = await getApplicationSupportDirectory();
    _cacheDir = Directory('${appDir.path}/thumbnails');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    // Spawn isolates for thumbnail generation
    for (int i = 0; i < _isolatePorts.length; i++) {
      final receivePort = ReceivePort();
      await Isolate.spawn(_thumbnailGeneratorIsolate, receivePort.sendPort);
      _isolatePorts[i] = await receivePort.first as SendPort;
    }

    _initialized = true;
  }

  // Generate cache key from file path
  String _getCacheKey(String filePath, int size) {
    final key = '$filePath:$size';
    return md5.convert(utf8.encode(key)).toString();
  }

  // Get thumbnail with 3-tier lookup
  Future<Uint8List?> getThumbnail(String filePath, {int size = 300}) async {
    final cacheKey = _getCacheKey(filePath, size);

    // 1. Check memory cache
    if (_memoryCache.containsKey(cacheKey)) {
      _updateLRU(cacheKey);
      return _memoryCache[cacheKey];
    }

    // 2. Check disk cache
    final diskFile = File('${_cacheDir!.path}/$cacheKey.jpg');
    if (await diskFile.exists()) {
      final bytes = await diskFile.readAsBytes();
      _addToMemoryCache(cacheKey, bytes);
      return bytes;
    }

    // 3. Generate thumbnail
    return await _generateThumbnail(filePath, size, cacheKey);
  }

  Future<Uint8List?> _generateThumbnail(
    String filePath,
    int size,
    String cacheKey,
  ) async {
    try {
      // Use available isolate from pool
      final isolateIndex = _lruKeys.length % _isolatePorts.length;
      final port = _isolatePorts[isolateIndex];

      if (port == null) {
        // Fallback to compute if isolate not ready
        return await compute(_generateThumbnailSync, {
          'path': filePath,
          'size': size,
        });
      }

      // Send to isolate
      final responsePort = ReceivePort();
      port.send({
        'path': filePath,
        'size': size,
        'responsePort': responsePort.sendPort,
      });

      final bytes = await responsePort.first as Uint8List?;

      if (bytes != null) {
        // Save to disk cache
        final diskFile = File('${_cacheDir!.path}/$cacheKey.jpg');
        await diskFile.writeAsBytes(bytes);

        // Add to memory cache
        _addToMemoryCache(cacheKey, bytes);
      }

      return bytes;
    } catch (e) {
      print('Thumbnail generation failed: $e');
      return null;
    }
  }

  void _addToMemoryCache(String key, Uint8List bytes) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      // Remove oldest entry
      final oldestKey = _lruKeys.removeAt(0);
      _memoryCache.remove(oldestKey);
    }

    _memoryCache[key] = bytes;
    _lruKeys.add(key);
  }

  void _updateLRU(String key) {
    _lruKeys.remove(key);
    _lruKeys.add(key);
  }

  // Isolate entry point
  static void _thumbnailGeneratorIsolate(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is Map) {
        final path = message['path'] as String;
        final size = message['size'] as int;
        final responsePort = message['responsePort'] as SendPort;

        final result = await _generateThumbnailSync({
          'path': path,
          'size': size,
        });

        responsePort.send(result);
      }
    });
  }

  static Future<Uint8List?> _generateThumbnailSync(
    Map<String, dynamic> params,
  ) async {
    try {
      final path = params['path'] as String;
      final size = params['size'] as int;

      final file = File(path);
      final bytes = await file.readAsBytes();

      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize maintaining aspect ratio
      final thumbnail = img.copyResize(
        image,
        width: size,
        height: size,
        interpolation: img.Interpolation.linear,
      );

      // Encode as JPEG with compression
      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 85));
    } catch (e) {
      return null;
    }
  }

  // Clear old cache entries
  Future<void> clearOldCache({Duration age = const Duration(days: 7)}) async {
    if (_cacheDir == null) return;

    final now = DateTime.now();
    final files = _cacheDir!.listSync();

    for (final file in files) {
      if (file is File) {
        final stat = await file.stat();
        if (now.difference(stat.modified) > age) {
          await file.delete();
        }
      }
    }
  }

  // Preload thumbnails for next batch
  Future<void> preloadBatch(List<String> filePaths, {int size = 300}) async {
    for (final path in filePaths) {
      // Fire and forget - will be cached when needed
      getThumbnail(path, size: size);
    }
  }
}

// ============================================
// 2. Optimized File Scanner with Streaming
// ============================================

// services/optimized_file_scanner.dart

class OptimizedFileScannerService {
  static Stream<List<FileItem>> scanDirectoryStream(
    String path,
    List<String> allowedExtensions,
  ) async* {
    final batchSize = 100;
    final batch = <FileItem>[];

    final queue = Queue<Directory>()..add(Directory(path));
    final Set<String> visited = {};

    while (queue.isNotEmpty) {
      final dir = queue.removeFirst();

      // Skip if already visited (prevent loops)
      if (visited.contains(dir.path)) continue;
      visited.add(dir.path);

      try {
        final entities = dir.listSync(followLinks: false);

        for (final entity in entities) {
          if (entity is Directory) {
            // Skip hidden and system folders
            final name = entity.path.split(Platform.pathSeparator).last;
            if (!name.startsWith('.') && !_isSystemFolder(name)) {
              queue.add(entity);
            }
          } else if (entity is File) {
            final ext = entity.path.split('.').last.toLowerCase();

            if (allowedExtensions.contains(ext)) {
              final stat = await entity.stat();

              batch.add(
                FileItem(
                  path: entity.path,
                  name: entity.path.split(Platform.pathSeparator).last,
                  size: stat.size,
                  extension: ext,
                  modifiedDate: stat.modified,
                  selected: false,
                ),
              );

              // Yield batch when full
              if (batch.length >= batchSize) {
                yield List<FileItem>.from(batch);
                batch.clear();
              }
            }
          }
        }
      } catch (e) {
        // Skip inaccessible directories
        print('Skipped directory: ${dir.path}');
      }
    }

    // Yield remaining items
    if (batch.isNotEmpty) {
      yield batch;
    }
  }

  static bool _isSystemFolder(String name) {
    const systemFolders = [
      'System Volume Information',
      '\$RECYCLE.BIN',
      'Windows',
      'Program Files',
      'Program Files (x86)',
      'AppData',
      'node_modules',
      '.git',
    ];
    return systemFolders.contains(name);
  }

  // Parallel scanning using isolates
  static Future<List<FileItem>> scanDirectoryParallel(
    String path,
    List<String> allowedExtensions,
  ) async {
    final allFiles = <FileItem>[];

    await for (final batch in scanDirectoryStream(path, allowedExtensions)) {
      allFiles.addAll(batch);
    }

    return allFiles;
  }
}

// ============================================
// 3. Database Service for Metadata
// ============================================

// services/file_database_service.dart

class FileDatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = await getDatabasesPath();
    // final fullPath = path.join(dbPath, 'file_manager.db');

    _database = await openDatabase(
      '$dbPath/file_manager.db',
      version: 1,
      onCreate: _onCreate,
    );

    return _database!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE files (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        extension TEXT NOT NULL,
        size INTEGER NOT NULL,
        modified INTEGER NOT NULL,
        thumbnail_path TEXT,
        category TEXT,
        tags TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Indexes for fast queries
    await db.execute('CREATE INDEX idx_extension ON files(extension)');
    await db.execute('CREATE INDEX idx_category ON files(category)');
    await db.execute('CREATE INDEX idx_modified ON files(modified)');
    await db.execute('CREATE INDEX idx_size ON files(size)');

    // Full-text search
    await db.execute('''
      CREATE VIRTUAL TABLE files_fts USING fts5(
        name,
        path,
        content=files,
        content_rowid=rowid
      )
    ''');
  }

  // Batch insert for performance
  static Future<void> insertFiles(List<FileItem> files) async {
    final db = await database;
    final batch = db.batch();

    for (final file in files) {
      final id = _generateId(file.path);
      batch.insert('files', {
        'id': id,
        'path': file.path,
        'name': file.name,
        'extension': file.extension,
        'size': file.size,
        'modified': file.modifiedDate.millisecondsSinceEpoch,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Update FTS index
      batch.insert('files_fts', {
        'rowid': id.hashCode,
        'name': file.name,
        'path': file.path,
      });
    }

    await batch.commit(noResult: true);
  }

  // Fast search using FTS5
  static Future<List<FileItem>> searchFiles(String query) async {
    final db = await database;

    final results = await db.rawQuery(
      '''
      SELECT f.* FROM files f
      JOIN files_fts fts ON f.rowid = fts.rowid
      WHERE files_fts MATCH ?
      ORDER BY rank
      LIMIT 100
    ''',
      [query],
    );

    return results.map((row) => _fileFromMap(row)).toList();
  }

  // Filtered query with pagination
  static Future<List<FileItem>> getFiles({
    String? extension,
    String? category,
    int? minSize,
    int? maxSize,
    DateTime? modifiedAfter,
    DateTime? modifiedBefore,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];

    if (extension != null) {
      where.add('extension = ?');
      args.add(extension);
    }

    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }

    if (minSize != null) {
      where.add('size >= ?');
      args.add(minSize);
    }

    if (maxSize != null) {
      where.add('size <= ?');
      args.add(maxSize);
    }

    if (modifiedAfter != null) {
      where.add('modified >= ?');
      args.add(modifiedAfter.millisecondsSinceEpoch);
    }

    if (modifiedBefore != null) {
      where.add('modified <= ?');
      args.add(modifiedBefore.millisecondsSinceEpoch);
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final results = await db.rawQuery(
      '''
      SELECT * FROM files
      $whereClause
      ORDER BY modified DESC
      LIMIT ? OFFSET ?
    ''',
      [...args, limit, offset],
    );

    return results.map((row) => _fileFromMap(row)).toList();
  }

  static FileItem _fileFromMap(Map<String, dynamic> map) {
    return FileItem(
      path: map['path'],
      name: map['name'],
      extension: map['extension'],
      size: map['size'],
      // modifiedDate: DateTime.fromMillisecondsSinceEpoch(map['modified']),
      selected: false,
      modifiedDate: DateTime.fromMillisecondsSinceEpoch(map['modified']),
    );
  }

  static String _generateId(String path) {
    return md5.convert(utf8.encode(path)).toString();
  }

  // Cleanup old entries
  static Future<void> cleanupOldEntries(Duration age) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(age).millisecondsSinceEpoch;

    await db.delete('files', where: 'created_at < ?', whereArgs: [cutoff]);
  }
}

// ============================================
// 4. Memory-Efficient Image Widget
// ============================================

// widgets/efficient_thumbnail_image.dart

class EfficientThumbnailImage extends StatefulWidget {
  final String filePath;
  final int size;
  final BoxFit fit;

  const EfficientThumbnailImage({
    super.key,
    required this.filePath,
    this.size = 300,
    this.fit = BoxFit.cover,
  });

  @override
  State<EfficientThumbnailImage> createState() =>
      _EfficientThumbnailImageState();
}

class _EfficientThumbnailImageState extends State<EfficientThumbnailImage>
    with AutomaticKeepAliveClientMixin {
  Uint8List? _thumbnailBytes;
  bool _loading = true;
  bool _error = false;

  @override
  bool get wantKeepAlive => _thumbnailBytes != null;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(EfficientThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.size != widget.size) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final bytes = await ThumbnailCacheService().getThumbnail(
        widget.filePath,
        size: widget.size,
      );

      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _loading = false;
          _error = bytes == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_loading) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error || _thumbnailBytes == null) {
      return Container(
        color: Colors.grey.shade100,
        child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 48),
      );
    }

    return Image.memory(
      _thumbnailBytes!,
      fit: widget.fit,
      gaplessPlayback: true,
      // Critical: Don't decode full resolution
      cacheWidth: widget.size,
      cacheHeight: widget.size,
    );
  }
}

// ============================================
// 5. Performance Monitor Widget
// ============================================

class PerformanceMonitor extends StatefulWidget {
  final Widget child;

  const PerformanceMonitor({super.key, required this.child});

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  double _fps = 60.0;
  int _frameCount = 0;
  DateTime _lastTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    _frameCount++;

    final now = DateTime.now();
    final elapsed = now.difference(_lastTime);

    if (elapsed.inMilliseconds >= 1000) {
      setState(() {
        _fps = (_frameCount / elapsed.inMilliseconds) * 1000;
        _frameCount = 0;
        _lastTime = now;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (kDebugMode)
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _fps < 50
                    ? Colors.red.withOpacity(0.9)
                    : Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'FPS: ${_fps.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
