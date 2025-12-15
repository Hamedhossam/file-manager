import 'package:equatable/equatable.dart';
import '../../../core/models/file_item.dart';

class FileManagerState extends Equatable {
  final bool loading;
  final List<FileItem> files;
  final List<FileItem> filteredFiles;
  final String? selectedPath;
  final String? activeExtension;
  final String? error;

  const FileManagerState({
    this.loading = false,
    this.files = const [],
    this.filteredFiles = const [],
    this.selectedPath,
    this.activeExtension,
    this.error,
  });

  FileManagerState copyWith({
    bool? loading,
    List<FileItem>? files,
    List<FileItem>? filteredFiles,
    String? selectedPath,
    String? activeExtension,
    String? error,
  }) {
    return FileManagerState(
      loading: loading ?? this.loading,
      files: files ?? this.files,
      filteredFiles: filteredFiles ?? this.filteredFiles,
      selectedPath: selectedPath ?? this.selectedPath,
      activeExtension: activeExtension ?? this.activeExtension,
      error: error,
    );
  }

  int get selectedCount => files.where((f) => f.selected).length;

  bool get hasSelection => selectedCount > 0;

  @override
  List<Object?> get props => [
    loading,
    files,
    filteredFiles,
    selectedPath,
    activeExtension,
    error,
  ];
}
