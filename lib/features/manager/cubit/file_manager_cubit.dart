import 'package:flutter_bloc/flutter_bloc.dart';
import 'file_manager_state.dart';
import '../../../core/services/file_scanner_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class FileManagerCubit extends Cubit<FileManagerState> {
  FileManagerCubit() : super(const FileManagerState());

  final List<String> allowedExtensions = ['psd', 'jpg', 'png'];

  Future<void> pickAndScanFolder() async {
    emit(state.copyWith(loading: true));

    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) {
        emit(state.copyWith(loading: false));
        return;
      }

      final files = await FileScannerService.scanDirectory(
        path,
        allowedExtensions,
      );

      emit(
        state.copyWith(
          loading: false,
          files: files,
          filteredFiles: files,
          selectedPath: path,
          activeExtension: 'all',
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: 'Failed to scan folder: $e'));
    }
  }

  void filterByExtension(String? ext) {
    final filteredList = ext == null || ext == 'all'
        ? state.files
        : state.files.where((f) => f.extension == ext).toList();

    emit(
      state.copyWith(
        filteredFiles: filteredList,
        activeExtension: ext ?? 'all',
      ),
    );
  }

  // FIX: Toggle selection using file path as identifier instead of index
  void toggleSelection(String filePath) {
    final updatedFiles = state.files.map((file) {
      if (file.path == filePath) {
        return file.copyWith(selected: !file.selected);
      }
      return file;
    }).toList();

    // Reapply current filter to maintain consistency
    final filteredList =
        state.activeExtension == null || state.activeExtension == 'all'
        ? updatedFiles
        : updatedFiles
              .where((f) => f.extension == state.activeExtension)
              .toList();

    emit(state.copyWith(files: updatedFiles, filteredFiles: filteredList));
  }

  // New: Select/Deselect all visible files
  void toggleSelectAll() {
    final allSelected = state.filteredFiles.every((f) => f.selected);

    final updatedFiles = state.files.map((file) {
      // Only toggle files that are currently visible
      if (state.filteredFiles.any((f) => f.path == file.path)) {
        return file.copyWith(selected: !allSelected);
      }
      return file;
    }).toList();

    final filteredList =
        state.activeExtension == null || state.activeExtension == 'all'
        ? updatedFiles
        : updatedFiles
              .where((f) => f.extension == state.activeExtension)
              .toList();

    emit(state.copyWith(files: updatedFiles, filteredFiles: filteredList));
  }

  // New: Clear all selections
  void clearSelection() {
    final updatedFiles = state.files.map((file) {
      return file.copyWith(selected: false);
    }).toList();

    final filteredList =
        state.activeExtension == null || state.activeExtension == 'all'
        ? updatedFiles
        : updatedFiles
              .where((f) => f.extension == state.activeExtension)
              .toList();

    emit(state.copyWith(files: updatedFiles, filteredFiles: filteredList));
  }

  Future<void> moveSelectedFiles() async {
    final selectedFiles = state.files.where((f) => f.selected).toList();

    if (selectedFiles.isEmpty) {
      emit(state.copyWith(error: 'No files selected'));
      return;
    }

    final targetDir = await FilePicker.platform.getDirectoryPath();
    if (targetDir == null) return;

    emit(state.copyWith(loading: true));

    try {
      int successCount = 0;
      int failCount = 0;

      for (final file in selectedFiles) {
        try {
          final newPath = '$targetDir/${file.name}';
          await File(file.path).rename(newPath);
          successCount++;
        } catch (e) {
          failCount++;
          print('Failed to move ${file.name}: $e');
        }
      }

      // Remove successfully moved files
      final remaining = state.files
          .where((f) => !f.selected || failCount > 0)
          .toList();

      // Reapply filter
      final filteredList =
          state.activeExtension == null || state.activeExtension == 'all'
          ? remaining
          : remaining
                .where((f) => f.extension == state.activeExtension)
                .toList();

      emit(
        state.copyWith(
          loading: false,
          files: remaining,
          filteredFiles: filteredList,
          error: failCount > 0
              ? 'Moved $successCount files, failed $failCount'
              : 'Successfully moved $successCount files',
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: 'Failed to move files: $e'));
    }
  }

  // New: Refresh current folder
  Future<void> refreshFolder() async {
    if (state.selectedPath != null) {
      emit(state.copyWith(loading: true));

      try {
        final files = await FileScannerService.scanDirectory(
          state.selectedPath!,
          allowedExtensions,
        );

        final filteredList =
            state.activeExtension == null || state.activeExtension == 'all'
            ? files
            : files.where((f) => f.extension == state.activeExtension).toList();

        emit(
          state.copyWith(
            loading: false,
            files: files,
            filteredFiles: filteredList,
            error: null,
          ),
        );
      } catch (e) {
        emit(state.copyWith(loading: false, error: 'Failed to refresh: $e'));
      }
    }
  }

  // New: Get selection info
  int get selectedCount => state.files.where((f) => f.selected).length;

  int get totalSize => state.files
      .where((f) => f.selected)
      .fold(0, (sum, file) => sum + file.size);

  void clearError() {
    emit(state.copyWith(error: null));
  }
}
