import 'dart:async';
import 'package:files_manager/core/models/file_item.dart';
import 'package:files_manager/features/manager/cubit/file_manager_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EnhancedFileManagerCubit extends Cubit<EnhancedFileManagerState> {
  EnhancedFileManagerCubit() : super(const EnhancedFileManagerState());

  Timer? _searchDebouncer;

  // Change view mode
  void setViewMode(ViewMode mode) {
    emit(state.copyWith(viewMode: mode));
  }

  // Adjust grid size
  void setGridSize(double size) {
    emit(state.copyWith(gridSize: size.clamp(1.0, 3.0)));
  }

  // Search with debouncing (performance optimization)
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
      return file.name.toLowerCase().contains(searchLower);
    }).toList();

    emit(
      state.copyWith(
        searchQuery: query,
        filteredFiles: _applySorting(filtered),
        currentPage: 0,
      ),
    );
  }

  // Sorting
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
        sorted.sort((a, b) => a.name.compareTo(b.name));
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

  // Load more items (pagination)
  void loadMore() {
    if (state.loading) return;

    final hasMore =
        ((state.currentPage + 1) * state.itemsPerPage) <
        state.filteredFiles.length;

    if (hasMore) {
      emit(
        state.copyWith(currentPage: state.currentPage + 1, hasMore: hasMore),
      );
    }
  }

  // Optimized selection using Set
  void toggleSelection(String filePath) {
    final newSelection = Set<String>.from(state.selectedFilePaths);

    if (newSelection.contains(filePath)) {
      newSelection.remove(filePath);
    } else {
      newSelection.add(filePath);
    }

    emit(state.copyWith(selectedFilePaths: newSelection));
  }

  // Bulk operations
  void selectAll() {
    final allPaths = state.filteredFiles.map((f) => f.path).toSet();
    emit(state.copyWith(selectedFilePaths: allPaths));
  }

  void clearSelection() {
    emit(state.copyWith(selectedFilePaths: {}));
  }

  // Select range (Shift+Click)
  void selectRange(int fromIndex, int toIndex) {
    final start = fromIndex < toIndex ? fromIndex : toIndex;
    final end = fromIndex < toIndex ? toIndex : fromIndex;

    final rangePaths = state.visibleFiles
        .sublist(start, end + 1)
        .map((f) => f.path)
        .toSet();

    emit(
      state.copyWith(
        selectedFilePaths: {...state.selectedFilePaths, ...rangePaths},
      ),
    );
  }

  @override
  Future<void> close() {
    _searchDebouncer?.cancel();
    return super.close();
  }
}
