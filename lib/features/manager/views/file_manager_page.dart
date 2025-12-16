// ============================================
// COMPLETE MODERN UI IMPLEMENTATION
// ============================================

// Enhanced File Manager Page with Modern UI
// pages/enhanced_file_manager_page.dart

import 'dart:io';

import 'package:files_manager/core/models/file_item.dart';
import 'package:files_manager/core/services/thumbnail_cache_service.dart';
import 'package:files_manager/features/manager/cubit/file_manager_cubit.dart';
import 'package:files_manager/features/manager/cubit/file_manager_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EnhancedFileManagerPage extends StatefulWidget {
  const EnhancedFileManagerPage({super.key});

  @override
  State<EnhancedFileManagerPage> createState() =>
      _EnhancedFileManagerPageState();
}

class _EnhancedFileManagerPageState extends State<EnhancedFileManagerPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  int? _lastSelectedIndex;

  @override
  void initState() {
    super.initState();

    // Setup lazy loading
    _scrollController.addListener(_onScroll);

    // Initialize services
    ThumbnailCacheService().initialize();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      context.read<EnhancedFileManagerCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: BlocConsumer<EnhancedFileManagerCubit, EnhancedFileManagerState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Dismiss',
                  onPressed: () {},
                  // context.read<EnhancedFileManagerCubit>().clearError(),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // Modern App Bar
              _buildModernAppBar(context, state, theme),

              // Toolbar with filters and view controls
              _buildToolbar(context, state, theme),

              // Main content area
              Expanded(child: _buildContent(context, state, theme)),

              // Bottom action bar (when items selected)
              if (state.hasSelection) _buildActionBar(context, state, theme),
            ],
          );
        },
      ),

      // Floating quick actions
      floatingActionButton: _buildQuickActions(context),
    );
  }

  // ============================================
  // Modern App Bar with Glass Morphism
  // ============================================

  Widget _buildModernAppBar(
    BuildContext context,
    EnhancedFileManagerState state,
    ThemeData theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // App icon and title
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_special,
                  color: theme.colorScheme.onPrimary,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'File Manager',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (state.selectedPath != null)
                    Text(
                      '${state.totalFilesScanned} files',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),

              const Spacer(),

              // Quick stats
              if (state.hasSelection)
                _buildSelectionChip(context, state, theme),

              const SizedBox(width: 8),

              // Settings button
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => _showSettings(context),
              ),

              // Theme toggle
              IconButton(
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () {
                  // Toggle theme logic
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionChip(
    BuildContext context,
    EnhancedFileManagerState state,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '${state.selectedCount} selected',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // Enhanced Toolbar
  // ============================================

  Widget _buildToolbar(
    BuildContext context,
    EnhancedFileManagerState state,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Search bar
              Expanded(flex: 2, child: _buildSearchBar(context, theme)),

              const SizedBox(width: 12),

              // Filter dropdown
              _buildFilterDropdown(context, state, theme),

              const SizedBox(width: 12),

              // Sort button
              _buildSortButton(context, state, theme),

              const SizedBox(width: 12),

              // View mode toggle
              _buildViewModeToggle(context, state, theme),

              const SizedBox(width: 12),

              // Grid size slider
              if (state.viewMode == ViewMode.grid)
                _buildGridSizeControl(context, state, theme),
            ],
          ),

          const SizedBox(height: 12),

          // Quick filter chips
          _buildQuickFilters(context, state, theme),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, ThemeData theme) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search files...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  context.read<EnhancedFileManagerCubit>().search('');
                },
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      onChanged: (value) {
        context.read<EnhancedFileManagerCubit>().search(value);
      },
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context,
    EnhancedFileManagerState state,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: state.activeExtension ?? 'all',
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Files')),
          DropdownMenuItem(value: 'psd', child: Text('PSD')),
          DropdownMenuItem(value: 'jpg', child: Text('JPG')),
          DropdownMenuItem(value: 'png', child: Text('PNG')),
        ],
        onChanged: (value) {
          // context.read<EnhancedFileManagerCubit>().filterByExtension(
          //   value == 'all' ? null : value,
          // );
        },
      ),
    );
  }

  Widget _buildSortButton(
    BuildContext context,
    EnhancedFileManagerState state,
    ThemeData theme,
  ) {
    return PopupMenuButton<SortBy>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 20, color: theme.colorScheme.onSurface),
            const SizedBox(width: 8),
            Text(
              _getSortLabel(state.sortBy),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(width: 4),
            Icon(
              state.sortOrder == SortOrder.asc
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 16,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: SortBy.name, child: Text('Name')),
        const PopupMenuItem(value: SortBy.date, child: Text('Date')),
        const PopupMenuItem(value: SortBy.size, child: Text('Size')),
        const PopupMenuItem(value: SortBy.type, child: Text('Type')),
      ],
      onSelected: (sortBy) {
        context.read<EnhancedFileManagerCubit>().setSorting(sortBy);
      },
    );
  }

  String _getSortLabel(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.name:
        return 'Name';
      case SortBy.date:
        return 'Date';
      case SortBy.size:
        return 'Size';
      case SortBy.type:
        return 'Type';
    }
  }

  Widget _buildViewModeToggle(
    BuildContext context,
    EnhancedFileManagerState state,
    ThemeData theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewModeButton(
            context,
            Icons.grid_view,
            ViewMode.grid,
            state.viewMode == ViewMode.grid,
            theme,
          ),
          _viewModeButton(
            context,
            Icons.view_list,
            ViewMode.list,
            state.viewMode == ViewMode.list,
            theme,
          ),
          _viewModeButton(
            context,
            Icons.collections,
            ViewMode.gallery,
            state.viewMode == ViewMode.gallery,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _viewModeButton(
    BuildContext context,
    IconData icon,
    ViewMode mode,
    bool isActive,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: () {
        context.read<EnhancedFileManagerCubit>().setViewMode(mode);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildGridSizeControl(
    BuildContext context,
    EnhancedFileManagerState state,
    ThemeData theme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.photo_size_select_small,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        SizedBox(
          width: 100,
          child: Slider(
            value: state.gridSize,
            min: 1.0,
            max: 3.0,
            divisions: 2,
            onChanged: (value) {
              context.read<EnhancedFileManagerCubit>().setGridSize(value);
            },
          ),
        ),
        Icon(
          Icons.photo_size_select_large,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _buildQuickFilters(
    BuildContext context,
    EnhancedFileManagerState state,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Text(
          'Quick filters:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),

        _filterChip(context, 'Today', Icons.today, theme),
        _filterChip(context, 'This Week', Icons.date_range, theme),
        _filterChip(context, 'Large Files', Icons.storage, theme),
        _filterChip(context, 'Recent', Icons.history, theme),

        const Spacer(),

        // Select all button
        if (state.filteredFiles.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              final allSelected =
                  state.selectedCount == state.filteredFiles.length;
              if (allSelected) {
                context.read<EnhancedFileManagerCubit>().clearSelection();
              } else {
                context.read<EnhancedFileManagerCubit>().selectAll();
              }
            },
            icon: Icon(
              state.selectedCount == state.filteredFiles.length
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
            ),
            label: const Text('Select All'),
          ),
      ],
    );
  }

  Widget _filterChip(
    BuildContext context,
    String label,
    IconData icon,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        selected: false,
        onSelected: (selected) {
          // Apply filter
        },
      ),
    );
  }

  // ============================================
  // Content Area
  // ============================================

  Widget _buildContent(
    BuildContext context,
    EnhancedFileManagerState state,
    ThemeData theme,
  ) {
    if (state.loading && state.files.isEmpty) {
      return _buildLoadingState(theme);
    }

    if (state.files.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    if (state.filteredFiles.isEmpty) {
      return _buildNoResultsState(theme);
    }

    switch (state.viewMode) {
      case ViewMode.grid:
        return _buildGridView(context, state);
      case ViewMode.list:
        return _buildListView(context, state);
      case ViewMode.gallery:
        return _buildGalleryView(context, state);
    }
  }

  Widget _buildGridView(BuildContext context, EnhancedFileManagerState state) {
    return ModernFileGrid(
      files: state.visibleFiles,
      selectedPaths: state.selectedFilePaths,
      gridSize: state.gridSize,
      onTap: (path) => _handleFileTap(context, path, state),
      onLoadMore: () => context.read<EnhancedFileManagerCubit>().loadMore(),
    );
  }

  void _handleFileTap(
    BuildContext context,
    String filePath,
    EnhancedFileManagerState state,
  ) {
    final isShiftPressed =
        RawKeyboard.instance.keysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        RawKeyboard.instance.keysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        );

    if (isShiftPressed && _lastSelectedIndex != null) {
      // Range selection
      final currentIndex = state.visibleFiles.indexWhere(
        (f) => f.path == filePath,
      );

      if (currentIndex != -1) {
        context.read<EnhancedFileManagerCubit>().selectRange(
          _lastSelectedIndex!,
          currentIndex,
        );
      }
    } else {
      // Single selection
      context.read<EnhancedFileManagerCubit>().toggleSelection(filePath);
      _lastSelectedIndex = state.visibleFiles.indexWhere(
        (f) => f.path == filePath,
      );
    }
  }

  // More view implementations...
  Widget _buildListView(BuildContext context, EnhancedFileManagerState state) {
    return ListView.builder(
      itemCount: state.visibleFiles.length,
      itemBuilder: (context, index) {
        final file = state.visibleFiles[index];
        return ListTile(
          leading: const Icon(Icons.insert_drive_file),
          title: Text(file.name),
          subtitle: Text('${file.size} bytes'),
          onTap: () => _handleFileTap(context, file.path, state),
        );
      },
    );
  }

  Widget _buildGalleryView(
    BuildContext context,
    EnhancedFileManagerState state,
  ) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: state.visibleFiles.length,
      itemBuilder: (context, index) {
        final file = state.visibleFiles[index];
        return GestureDetector(
          onTap: () => _handleFileTap(context, file.path, state),
          child: EfficientThumbnailImage(
            filePath: file.path,
            size: 400,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  // State widgets...
  Widget _buildLoadingState(ThemeData theme) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('No folder selected', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // context.read<EnhancedFileManagerCubit>().pickAndScanFolder();
            },
            icon: const Icon(Icons.folder),
            label: const Text('Select Folder'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text('No files found', style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }

  // Bottom action bar and FAB...
  Widget _buildActionBar(
    BuildContext context,
    EnhancedFileManagerState state,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '${state.selectedCount} files selected',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              context.read<EnhancedFileManagerCubit>().clearSelection();
            },
            child: const Text('Clear'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              // context.read<EnhancedFileManagerCubit>().moveSelectedFiles();
            },
            icon: const Icon(Icons.drive_file_move),
            label: const Text('Move'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'select_folder',
          onPressed: () {
            // context.read<EnhancedFileManagerCubit>().pickAndScanFolder();
          },
          child: const Icon(Icons.folder_open),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'refresh',
          onPressed: () {
            // context.read<EnhancedFileManagerCubit>().refreshFolder();
          },
          child: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  void _showSettings(BuildContext context) {
    // Show settings dialog
  }
}

class ModernFileGrid extends StatelessWidget {
  final List<FileItem> files;
  final Set<String> selectedPaths;
  final double gridSize;
  final Function(String) onTap;
  final VoidCallback? onLoadMore;

  const ModernFileGrid({
    super.key,
    required this.files,
    required this.selectedPaths,
    required this.gridSize,
    required this.onTap,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final itemSize = 120.0 + (gridSize * 40);
    final crossAxisCount = (MediaQuery.of(context).size.width / itemSize)
        .floor()
        .clamp(2, 8);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          final maxScroll = notification.metrics.maxScrollExtent;
          final currentScroll = notification.metrics.pixels;

          // Load more when 80% scrolled
          if (currentScroll >= maxScroll * 0.8) {
            onLoadMore?.call();
          }
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: files.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          final file = files[index];
          final isSelected = selectedPaths.contains(file.path);

          return ModernFileCard(
            file: file,
            isSelected: isSelected,
            size: gridSize,
            onTap: () => onTap(file.path),
          );
        },
      ),
    );
  }
}

class ModernFileCard extends StatefulWidget {
  final FileItem file;
  final bool isSelected;
  final double size;
  final VoidCallback onTap;

  const ModernFileCard({
    super.key,
    required this.file,
    required this.isSelected,
    required this.size,
    required this.onTap,
  });

  @override
  State<ModernFileCard> createState() => _ModernFileCardState();
}

class _ModernFileCardState extends State<ModernFileCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = ['jpg', 'png', 'jpeg'].contains(widget.file.extension);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? theme.colorScheme.primary
                    : (_isHovered
                          ? theme.colorScheme.outline
                          : theme.colorScheme.outlineVariant),
                width: widget.isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (_isHovered || widget.isSelected)
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Selection indicator
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: widget.isSelected
                              ? theme.colorScheme.onPrimary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ),

                  // Thumbnail
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: isImage
                          ? Hero(
                              tag: 'file_${widget.file.path}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(widget.file.path),
                                  fit: BoxFit.cover,
                                  cacheWidth: 300, // Performance optimization
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.insert_drive_file_outlined,
                              size: 48,
                              color: theme.colorScheme.secondary,
                            ),
                    ),
                  ),

                  // File info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? theme.colorScheme.primary.withOpacity(0.1)
                          : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(widget.file.size),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
