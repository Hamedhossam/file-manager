import 'dart:io';

import 'package:files_manager/core/models/file_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/file_manager_cubit.dart';
import '../cubit/file_manager_state.dart';

class FileManagerPage extends StatelessWidget {
  const FileManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desktop File Manager'),
        actions: [
          BlocBuilder<FileManagerCubit, FileManagerState>(
            builder: (context, state) {
              if (state.selectedCount > 0) {
                return Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${state.selectedCount} selected',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear Selection',
                      onPressed: () =>
                          context.read<FileManagerCubit>().clearSelection(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.drive_file_move),
                      tooltip: 'Move Selected Files',
                      onPressed: () =>
                          context.read<FileManagerCubit>().moveSelectedFiles(),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          if (context.watch<FileManagerCubit>().state.selectedPath != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => context.read<FileManagerCubit>().refreshFolder(),
            ),
        ],
      ),
      body: BlocConsumer<FileManagerCubit, FileManagerState>(
        listener: (context, state) {
          // Show error messages
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                action: SnackBarAction(
                  label: 'Dismiss',
                  onPressed: () =>
                      context.read<FileManagerCubit>().clearError(),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No folder selected',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.read<FileManagerCubit>().pickAndScanFolder(),
                    icon: const Icon(Icons.folder),
                    label: const Text('Select Folder'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Toolbar
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    // Path display
                    Expanded(
                      child: Text(
                        state.selectedPath ?? '',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Filter dropdown
                    const Text('Filter: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: state.activeExtension ?? 'all',
                      items: ['all', 'psd', 'jpg', 'png']
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        context.read<FileManagerCubit>().filterByExtension(
                          v == 'all' ? null : v,
                        );
                      },
                    ),

                    const SizedBox(width: 16),

                    // Select all button
                    if (state.filteredFiles.isNotEmpty)
                      TextButton.icon(
                        onPressed: () =>
                            context.read<FileManagerCubit>().toggleSelectAll(),
                        icon: Icon(
                          state.filteredFiles.every((f) => f.selected)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                        ),
                        label: const Text('Select All'),
                      ),
                  ],
                ),
              ),

              // File count info
              if (state.filteredFiles.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${state.filteredFiles.length} files',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      if (state.selectedCount > 0) ...[
                        const SizedBox(width: 16),
                        Text(
                          '${state.selectedCount} selected',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Grid
              Expanded(
                child: state.filteredFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.filter_alt_off,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No files match the current filter',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = (constraints.maxWidth / 180)
                              .floor()
                              .clamp(2, 6);

                          return GridView.builder(
                            padding: const EdgeInsets.all(10),
                            itemCount: state.filteredFiles.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.9,
                                ),
                            itemBuilder: (_, i) {
                              final file = state.filteredFiles[i];
                              return FileGridItem(
                                file: file,
                                onTap: () => context
                                    .read<FileManagerCubit>()
                                    .toggleSelection(file.path),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: BlocBuilder<FileManagerCubit, FileManagerState>(
        builder: (context, state) {
          if (state.files.isEmpty) return const SizedBox.shrink();

          return FloatingActionButton(
            onPressed: () =>
                context.read<FileManagerCubit>().pickAndScanFolder(),
            tooltip: 'Change Folder',
            child: const Icon(Icons.folder_open),
          );
        },
      ),
    );
  }
}

class FileGridItem extends StatelessWidget {
  final FileItem file;
  final VoidCallback onTap;

  const FileGridItem({super.key, required this.file, required this.onTap});

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isImage = ['jpg', 'png'].contains(file.extension);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: file.selected ? Colors.blue.shade50 : Colors.white,
          border: Border.all(
            color: file.selected ? Colors.blue : Colors.grey.shade300,
            width: file.selected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: file.selected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Checkbox indicator
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  file.selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: file.selected ? Colors.blue : Colors.grey,
                  size: 20,
                ),
              ),
            ),

            // Image/Icon
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(file.path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.red,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.insert_drive_file,
                        size: 50,
                        color: Colors.grey.shade600,
                      ),
              ),
            ),

            // File info
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: file.selected
                    ? Colors.blue.shade100
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(7),
                  bottomRight: Radius.circular(7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: file.selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatFileSize(file.size),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
