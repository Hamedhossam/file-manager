import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:files_manager/core/models/file_item.dart';
import 'package:files_manager/core/services/file_scanner_service.dart';
import 'package:files_manager/core/services/thumbnail_cache_service.dart';
import 'package:files_manager/features/manager/cubit/file_manager_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EnhancedFileManagerCubit extends Cubit<EnhancedFileManagerState> {
  EnhancedFileManagerCubit() : super(const EnhancedFileManagerState());

  Timer? _searchDebouncer;

  // Allowed file extensions for scanning
  final List<String> _allowedExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', // Images
    'psd', 'ai', 'sketch', // Design files
    'pdf', 'doc', 'docx', 'txt', // Documents
    'mp4', 'mov', 'avi', 'mkv', // Videos
    'mp3', 'wav', 'flac', // Audio
  ];

  // ============================================
  // FOLDER OPERATIONS
  // ============================================

  /// Pick a folder and scan it for files
  Future<void> pickAndScanFolder() async {
    try {
      emit(state.copyWith(loading: true, error: null));

      // Use file_picker to select directory
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        emit(state.copyWith(loading: false));
        return;
      }

      await _scanFolder(selectedDirectory);
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to pick folder: ${e.toString()}',
        ),
      );
    }
  }

  /// Scan a specific folder path
  Future<void> scanFolder(String folderPath) async {
    try {
      emit(state.copyWith(loading: true, error: null));
      await _scanFolder(folderPath);
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to scan folder: ${e.toString()}',
        ),
      );
    }
  }

  /// Internal method to scan folder and update state
  Future<void> _scanFolder(String folderPath) async {
    try {
      final startTime = DateTime.now();

      // Scan directory for files
      final scannedFiles = await FileScannerService.scanDirectory(
        folderPath,
        _allowedExtensions,
      );

      final scanDuration = DateTime.now().difference(startTime);

      // Update state with scanned files
      emit(
        state.copyWith(
          loading: false,
          selectedPath: folderPath,
          files: scannedFiles,
          filteredFiles: _applyFilters(scannedFiles),
          totalFilesScanned: scannedFiles.length,
          lastScanTime: DateTime.now(),
          currentPage: 0,
          error: null,
        ),
      );

      // Preload thumbnails for first batch
      _preloadThumbnails();

      print(
        '✅ Scanned ${scannedFiles.length} files in ${scanDuration.inMilliseconds}ms',
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Error scanning folder: ${e.toString()}',
        ),
      );
    }
  }

  /// Refresh current folder
  Future<void> refreshFolder() async {
    if (state.selectedPath == null) {
      emit(state.copyWith(error: 'No folder selected'));
      return;
    }

    await _scanFolder(state.selectedPath!);
  }

  // ============================================
  // FILTERING & SORTING
  // ============================================

  /// Filter files by extension
  void filterByExtension(String? extension) {
    emit(
      state.copyWith(
        activeExtension: extension,
        filteredFiles: _applyFilters(state.files),
        currentPage: 0,
      ),
    );
  }

  /// Change view mode
  void setViewMode(ViewMode mode) {
    emit(state.copyWith(viewMode: mode));
  }

  /// Adjust grid size
  void setGridSize(double size) {
    emit(state.copyWith(gridSize: size.clamp(1.0, 3.0)));
  }

  /// Search with debouncing (performance optimization)
  void search(String query) {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      emit(
        state.copyWith(
          searchQuery: '',
          filteredFiles: _applyFilters(state.files),
          currentPage: 0,
        ),
      );
      return;
    }

    final searchLower = query.toLowerCase();
    final filtered = state.files.where((file) {
      return file.name.toLowerCase().contains(searchLower) ||
          file.extension.toLowerCase().contains(searchLower);
    }).toList();

    emit(
      state.copyWith(
        searchQuery: query,
        filteredFiles: _applySorting(filtered),
        currentPage: 0,
      ),
    );
  }

  /// Set sorting method
  void setSorting(SortBy sortBy, [SortOrder? order]) {
    final newOrder =
        order ??
        (state.sortBy == sortBy && state.sortOrder == SortOrder.asc
            ? SortOrder.desc
            : SortOrder.asc);

    emit(
      state.copyWith(
        sortBy: sortBy,
        sortOrder: newOrder,
        filteredFiles: _applySorting(state.filteredFiles),
      ),
    );
  }

  List<FileItem> _applySorting(List<FileItem> files) {
    final sorted = List<FileItem>.from(files);

    switch (state.sortBy) {
      case SortBy.name:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case SortBy.date:
        sorted.sort((a, b) => a.modifiedDate.compareTo(b.modifiedDate));
        break;
      case SortBy.size:
        sorted.sort((a, b) => a.size.compareTo(b.size));
        break;
      case SortBy.type:
        sorted.sort((a, b) => a.extension.compareTo(b.extension));
        break;
    }

    if (state.sortOrder == SortOrder.desc) {
      return sorted.reversed.toList();
    }
    return sorted;
  }

  List<FileItem> _applyFilters(List<FileItem> files) {
    var filtered = files;

    // Extension filter
    if (state.activeExtension != null && state.activeExtension != 'all') {
      filtered = filtered
          .where((f) => f.extension == state.activeExtension)
          .toList();
    }

    // Search filter
    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered
          .where((f) => f.name.toLowerCase().contains(query))
          .toList();
    }

    return _applySorting(filtered);
  }

  // ============================================
  // PAGINATION
  // ============================================

  /// Load more items (pagination)
  void loadMore() {
    if (state.loading) return;

    final hasMore =
        ((state.currentPage + 1) * state.itemsPerPage) <
        state.filteredFiles.length;

    if (hasMore) {
      emit(
        state.copyWith(currentPage: state.currentPage + 1, hasMore: hasMore),
      );

      // Preload thumbnails for next batch
      _preloadThumbnails();
    }
  }

  // ============================================
  // SELECTION OPERATIONS
  // ============================================

  /// Toggle single file selection
  void toggleSelection(String filePath) {
    final newSelection = Set<String>.from(state.selectedFilePaths);

    if (newSelection.contains(filePath)) {
      newSelection.remove(filePath);
    } else {
      newSelection.add(filePath);
    }

    emit(state.copyWith(selectedFilePaths: newSelection));
  }

  /// Select all visible files
  void selectAll() {
    final allPaths = state.filteredFiles.map((f) => f.path).toSet();
    emit(state.copyWith(selectedFilePaths: allPaths));
  }

  /// Clear all selections
  void clearSelection() {
    emit(state.copyWith(selectedFilePaths: {}));
  }

  /// Select range (Shift+Click)
  void selectRange(int fromIndex, int toIndex) {
    final start = fromIndex < toIndex ? fromIndex : toIndex;
    final end = fromIndex < toIndex ? toIndex : fromIndex;

    final rangePaths = state.visibleFiles
        .sublist(start, (end + 1).clamp(0, state.visibleFiles.length))
        .map((f) => f.path)
        .toSet();

    emit(
      state.copyWith(
        selectedFilePaths: {...state.selectedFilePaths, ...rangePaths},
      ),
    );
  }

  // ============================================
  // FILE OPERATIONS
  // ============================================

  /// Move selected files to a new location
  Future<void> moveSelectedFiles() async {
    if (!state.hasSelection) {
      emit(state.copyWith(error: 'No files selected'));
      return;
    }

    try {
      emit(state.copyWith(loading: true));

      // Pick destination folder
      String? destinationPath = await FilePicker.platform.getDirectoryPath();

      if (destinationPath == null) {
        emit(state.copyWith(loading: false));
        return;
      }

      // TODO: Implement actual file moving logic
      // This would involve:
      // 1. Moving files to destination
      // 2. Updating the file list
      // 3. Clearing selection

      emit(state.copyWith(loading: false, selectedFilePaths: {}, error: null));

      // Refresh to update file list
      await refreshFolder();
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to move files: ${e.toString()}',
        ),
      );
    }
  }

  /// Delete selected files
  Future<void> deleteSelectedFiles() async {
    if (!state.hasSelection) {
      emit(state.copyWith(error: 'No files selected'));
      return;
    }

    try {
      emit(state.copyWith(loading: true));

      // TODO: Implement actual file deletion logic
      // This should include confirmation dialog

      emit(state.copyWith(loading: false, selectedFilePaths: {}, error: null));

      // Refresh to update file list
      await refreshFolder();
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to delete files: ${e.toString()}',
        ),
      );
    }
  }

  /// Copy selected files
  Future<void> copySelectedFiles() async {
    if (!state.hasSelection) {
      emit(state.copyWith(error: 'No files selected'));
      return;
    }

    try {
      emit(state.copyWith(loading: true));

      // Pick destination folder
      String? destinationPath = await FilePicker.platform.getDirectoryPath();

      if (destinationPath == null) {
        emit(state.copyWith(loading: false));
        return;
      }

      // TODO: Implement actual file copying logic

      emit(state.copyWith(loading: false, error: null));
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to copy files: ${e.toString()}',
        ),
      );
    }
  }

  // ============================================
  // ERROR HANDLING
  // ============================================

  /// Clear error message
  void clearError() {
    emit(state.copyWith(error: null));
  }

  // ============================================
  // PERFORMANCE OPTIMIZATION
  // ============================================

  /// Preload thumbnails for visible files
  void _preloadThumbnails() {
    final visibleFiles = state.visibleFiles;
    final imagePaths = visibleFiles
        .where(
          (f) => [
            'jpg',
            'jpeg',
            'png',
            'gif',
            'bmp',
            'webp',
          ].contains(f.extension.toLowerCase()),
        )
        .map((f) => f.path)
        .toList();

    if (imagePaths.isNotEmpty) {
      ThumbnailCacheService().preloadBatch(imagePaths, size: 300);
    }
  }

  // ============================================
  // QUICK FILTERS
  // ============================================

  /// Filter files modified today
  void filterToday() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final filtered = state.files.where((file) {
      return file.modifiedDate.isAfter(startOfDay);
    }).toList();

    emit(
      state.copyWith(filteredFiles: _applySorting(filtered), currentPage: 0),
    );
  }

  /// Filter files modified this week
  void filterThisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    final filtered = state.files.where((file) {
      return file.modifiedDate.isAfter(startOfWeekDay);
    }).toList();

    emit(
      state.copyWith(filteredFiles: _applySorting(filtered), currentPage: 0),
    );
  }

  /// Filter large files (>10MB)
  void filterLargeFiles() {
    const tenMB = 10 * 1024 * 1024;

    final filtered = state.files.where((file) {
      return file.size > tenMB;
    }).toList();

    emit(
      state.copyWith(filteredFiles: _applySorting(filtered), currentPage: 0),
    );
  }

  /// Filter recently modified files (last 7 days)
  void filterRecent() {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    final filtered = state.files.where((file) {
      return file.modifiedDate.isAfter(sevenDaysAgo);
    }).toList();

    emit(
      state.copyWith(filteredFiles: _applySorting(filtered), currentPage: 0),
    );
  }

  /// Reset all filters
  void resetFilters() {
    emit(
      state.copyWith(
        activeExtension: null,
        searchQuery: '',
        filteredFiles: _applySorting(state.files),
        currentPage: 0,
      ),
    );
  }

  // ============================================
  // CLEANUP
  // ============================================

  @override
  Future<void> close() {
    _searchDebouncer?.cancel();
    return super.close();
  }
}
