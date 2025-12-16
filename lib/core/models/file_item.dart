import 'package:equatable/equatable.dart';

class FileItem extends Equatable {
  final String path;
  final String name;
  final String extension;
  final bool selected;
  final int size;
  final DateTime modifiedDate;

  const FileItem({
    required this.path,
    required this.name,
    required this.extension,
    this.selected = false,
    required this.size,
    required this.modifiedDate,
  });

  // IMPORTANT: Use copyWith to create new instances instead of mutating
  FileItem copyWith({
    String? path,
    String? name,
    String? extension,
    bool? selected,
    int? size,
    DateTime? modifiedDate,
  }) {
    return FileItem(
      path: path ?? this.path,
      name: name ?? this.name,
      extension: extension ?? this.extension,
      selected: selected ?? this.selected,
      size: size ?? this.size,
      modifiedDate: modifiedDate ?? this.modifiedDate,
    );
  }

  @override
  List<Object?> get props => [
    path,
    name,
    extension,
    selected,
    size,
    modifiedDate,
  ];
}
