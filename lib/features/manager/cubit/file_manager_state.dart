import 'package:equatable/equatable.dart';
import '../../../core/models/file_item.dart';

enum ViewMode { grid, list, gallery }

enum SortBy { name, date, size, type }

enum SortOrder { asc, desc }

class EnhancedFileManagerState extends Equatable {
  final bool loading;
  final List<FileItem> files;
  final List<FileItem> filteredFiles;
  final Set<String> selectedFilePaths; // Changed to Set for O(1) lookup
  final String? selectedPath;
  final String? activeExtension;
  final String? error;

  // New UI state
  final ViewMode viewMode;
  final double gridSize; // 1.0 = small, 2.0 = medium, 3.0 = large
  final SortBy sortBy;
  final SortOrder sortOrder;
  final String searchQuery;

  // Pagination
  final int currentPage;
  final int itemsPerPage;
  final bool hasMore;

  // Performance tracking
  final int totalFilesScanned;
  final DateTime? lastScanTime;

  const EnhancedFileManagerState({
    this.loading = false,
    this.files = const [],
    this.filteredFiles = const [],
    this.selectedFilePaths = const {},
    this.selectedPath,
    this.activeExtension,
    this.error,
    this.viewMode = ViewMode.grid,
    this.gridSize = 2.0,
    this.sortBy = SortBy.name,
    this.sortOrder = SortOrder.asc,
    this.searchQuery = '',
    this.currentPage = 0,
    this.itemsPerPage = 100,
    this.hasMore = false,
    this.totalFilesScanned = 0,
    this.lastScanTime,
  });

  EnhancedFileManagerState copyWith({
    bool? loading,
    List<FileItem>? files,
    List<FileItem>? filteredFiles,
    Set<String>? selectedFilePaths,
    String? selectedPath,
    String? activeExtension,
    String? error,
    ViewMode? viewMode,
    double? gridSize,
    SortBy? sortBy,
    SortOrder? sortOrder,
    String? searchQuery,
    int? currentPage,
    int? itemsPerPage,
    bool? hasMore,
    int? totalFilesScanned,
    DateTime? lastScanTime,
  }) {
    return EnhancedFileManagerState(
      loading: loading ?? this.loading,
      files: files ?? this.files,
      filteredFiles: filteredFiles ?? this.filteredFiles,
      selectedFilePaths: selectedFilePaths ?? this.selectedFilePaths,
      selectedPath: selectedPath ?? this.selectedPath,
      activeExtension: activeExtension ?? this.activeExtension,
      error: error,
      viewMode: viewMode ?? this.viewMode,
      gridSize: gridSize ?? this.gridSize,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      hasMore: hasMore ?? this.hasMore,
      totalFilesScanned: totalFilesScanned ?? this.totalFilesScanned,
      lastScanTime: lastScanTime ?? this.lastScanTime,
    );
  }

  int get selectedCount => selectedFilePaths.length;
  bool get hasSelection => selectedCount > 0;

  // Paginated visible files
  List<FileItem> get visibleFiles {
    final endIndex = ((currentPage + 1) * itemsPerPage).clamp(
      0,
      filteredFiles.length,
    );
    return filteredFiles.sublist(0, endIndex);
  }

  @override
  List<Object?> get props => [
    loading,
    files,
    filteredFiles,
    selectedFilePaths,
    selectedPath,
    activeExtension,
    error,
    viewMode,
    gridSize,
    sortBy,
    sortOrder,
    searchQuery,
    currentPage,
    itemsPerPage,
    hasMore,
    totalFilesScanned,
    lastScanTime,
  ];
}
