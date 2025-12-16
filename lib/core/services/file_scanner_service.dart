import 'dart:io';
import '../models/file_item.dart';

class FileScannerService {
  static Future<List<FileItem>> scanDirectory(
    String rootPath,
    List<String> extensions,
  ) async {
    final dir = Directory(rootPath);
    final List<FileItem> results = [];

    if (!dir.existsSync()) return results;

    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            final ext = entity.path.split('.').last.toLowerCase();

            if (extensions.contains(ext)) {
              final fileStat = await entity.stat();

              results.add(
                FileItem(
                  name: entity.uri.pathSegments.last,
                  path: entity.path,
                  extension: ext,
                  size: fileStat.size,
                  modifiedDate: fileStat.modified,
                  selected: false, // Always start unselected
                ),
              );
            }
          } catch (e) {
            // Skip files that can't be accessed (permissions, etc.)
            print('Error processing file ${entity.path}: $e');
            continue;
          }
        }
      }
    } catch (e) {
      print('Error scanning directory: $e');
    }

    // Sort by name for consistent ordering
    results.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return results;
  }

  // New: Get directory statistics
  static Future<DirectoryStats> getDirectoryStats(
    String rootPath,
    List<String> extensions,
  ) async {
    final files = await scanDirectory(rootPath, extensions);

    final totalSize = files.fold<int>(0, (sum, file) => sum + file.size);
    final extensionCounts = <String, int>{};

    for (var file in files) {
      extensionCounts[file.extension] =
          (extensionCounts[file.extension] ?? 0) + 1;
    }

    return DirectoryStats(
      totalFiles: files.length,
      totalSize: totalSize,
      extensionCounts: extensionCounts,
    );
  }
}

// New: Stats model
class DirectoryStats {
  final int totalFiles;
  final int totalSize;
  final Map<String, int> extensionCounts;

  DirectoryStats({
    required this.totalFiles,
    required this.totalSize,
    required this.extensionCounts,
  });
}
