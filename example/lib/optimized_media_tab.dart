// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:media_manager/media_manager.dart';

import 'main.dart' show MediaType, MediaPreviewScreen;
import 'memory_manager.dart';

// Optimized MediaTab with lazy loading and better memory management
class OptimizedMediaTab extends StatefulWidget {
  final MediaManager mediaManager;
  final MediaType mediaType;

  const OptimizedMediaTab({
    super.key,
    required this.mediaManager,
    required this.mediaType,
  });

  @override
  State<OptimizedMediaTab> createState() => _OptimizedMediaTabState();
}

class _OptimizedMediaTabState extends State<OptimizedMediaTab>
    with AutomaticKeepAliveClientMixin {
  List<String> _mediaPaths = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final MemoryManager _memoryManager = MemoryManager();
  final ImageLoadingQueue _loadingQueue = ImageLoadingQueue();

  // Pagination variables
  static const int _itemsPerPage = 50;
  int _currentPage = 0;
  List<String> _displayedPaths = [];
  bool _hasMoreItems = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMedia();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_hasMoreItems && !_isLoading) {
      setState(() {
        _currentPage++;
        final startIndex = _currentPage * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage).clamp(
          0,
          _mediaPaths.length,
        );

        if (startIndex < _mediaPaths.length) {
          _displayedPaths.addAll(_mediaPaths.sublist(startIndex, endIndex));
          _hasMoreItems = endIndex < _mediaPaths.length;
        } else {
          _hasMoreItems = false;
        }
      });
    }
  }

  Future<void> _loadMedia() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _displayedPaths.clear();
    });

    try {
      List<String> mediaPaths = [];

      switch (widget.mediaType) {
        case MediaType.image:
          mediaPaths = await widget.mediaManager.getAllImages();
          break;
        case MediaType.video:
          mediaPaths = await widget.mediaManager.getAllVideos();
          break;
        case MediaType.audio:
          mediaPaths = await widget.mediaManager.getAllAudio();
          break;
        case MediaType.document:
          mediaPaths = await widget.mediaManager.getAllDocuments();
          break;
        case MediaType.zip:
          mediaPaths = await widget.mediaManager.getAllZipFiles();
          break;
      }

      if (!mounted) return;

      setState(() {
        _mediaPaths = mediaPaths;
        _isLoading = false;

        // Load first page
        final firstPageEnd = _itemsPerPage.clamp(0, mediaPaths.length);
        _displayedPaths = mediaPaths.take(firstPageEnd).toList();
        _hasMoreItems = mediaPaths.length > _itemsPerPage;
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint('Error loading ${_getMediaTypeTitle()}: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ${_getMediaTypeTitle()}: $e')),
        );
      }
    }
  }

  String _getMediaTypeTitle() {
    switch (widget.mediaType) {
      case MediaType.image:
        return 'Images';
      case MediaType.video:
        return 'Videos';
      case MediaType.audio:
        return 'Audio Files';
      case MediaType.document:
        return 'Documents';
      case MediaType.zip:
        return 'Archives';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // Header with refresh button
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getMediaTypeTitle()} (${_mediaPaths.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_displayedPaths.length < _mediaPaths.length)
                      Text(
                        'Showing ${_displayedPaths.length} of ${_mediaPaths.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadMedia,
                      tooltip: 'Refresh ${_getMediaTypeTitle()}',
                    ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading media files...'),
                    ],
                  ),
                )
              : _displayedPaths.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _getMediaIconLarge(),
                      const SizedBox(height: 16),
                      Text(
                        'No ${_getMediaTypeTitle()} found',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _loadMedia,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tap to refresh'),
                      ),
                    ],
                  ),
                )
              : widget.mediaType == MediaType.image
              ? _buildOptimizedImageGrid()
              : widget.mediaType == MediaType.video
              ? _buildOptimizedVideoGrid()
              : _buildMediaList(),
        ),
      ],
    );
  }

  Widget _buildOptimizedImageGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: _displayedPaths.length + (_hasMoreItems ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the end
        if (index >= _displayedPaths.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final path = _displayedPaths[index];
        return _buildOptimizedImageTile(path);
      },
    );
  }

  Widget _buildOptimizedImageTile(String path) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaPreviewScreen(
              mediaPath: path,
              mediaType: widget.mediaType,
              mediaManager: widget.mediaManager,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _CachedImage(
            path: path,
            mediaManager: widget.mediaManager,
            memoryManager: _memoryManager,
            loadingQueue: _loadingQueue,
          ),
        ),
      ),
    );
  }

  Widget _buildOptimizedVideoGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: _displayedPaths.length + (_hasMoreItems ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _displayedPaths.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final path = _displayedPaths[index];
        return _buildOptimizedVideoTile(path);
      },
    );
  }

  Widget _buildOptimizedVideoTile(String path) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaPreviewScreen(
              mediaPath: path,
              mediaType: widget.mediaType,
              mediaManager: widget.mediaManager,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _CachedVideoThumbnail(
            path: path,
            mediaManager: widget.mediaManager,
            memoryManager: _memoryManager,
            loadingQueue: _loadingQueue,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _displayedPaths.length + (_hasMoreItems ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _displayedPaths.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final path = _displayedPaths[index];
        final fileName = path.split('/').last;

        return ListTile(
          leading: _getMediaIcon(),
          title: Text(fileName),
          subtitle: Text(path),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaPreviewScreen(
                  mediaPath: path,
                  mediaType: widget.mediaType,
                  mediaManager: widget.mediaManager,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _getMediaIcon() {
    switch (widget.mediaType) {
      case MediaType.image:
        return const Icon(Icons.image);
      case MediaType.video:
        return const Icon(Icons.video_file);
      case MediaType.audio:
        return const Icon(Icons.audio_file);
      case MediaType.document:
        return const Icon(Icons.insert_drive_file);
      case MediaType.zip:
        return const Icon(Icons.archive);
    }
  }

  Widget _getMediaIconLarge() {
    switch (widget.mediaType) {
      case MediaType.image:
        return const Icon(Icons.image, size: 64, color: Colors.grey);
      case MediaType.video:
        return const Icon(Icons.video_file, size: 64, color: Colors.grey);
      case MediaType.audio:
        return const Icon(Icons.audio_file, size: 64, color: Colors.grey);
      case MediaType.document:
        return const Icon(
          Icons.insert_drive_file,
          size: 64,
          color: Colors.grey,
        );
      case MediaType.zip:
        return const Icon(Icons.archive, size: 64, color: Colors.grey);
    }
  }

  @override
  bool get wantKeepAlive => true;
}

// Cached Image Widget with lazy loading
class _CachedImage extends StatefulWidget {
  final String path;
  final MediaManager mediaManager;
  final MemoryManager memoryManager;
  final ImageLoadingQueue loadingQueue;

  const _CachedImage({
    required this.path,
    required this.mediaManager,
    required this.memoryManager,
    required this.loadingQueue,
  });

  @override
  State<_CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<_CachedImage> {
  bool _isLoading = false;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    // Check cache first
    final cachedData = widget.memoryManager.getCachedImage(widget.path);
    if (cachedData != null) {
      return Image.memory(
        cachedData,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (_hasError) {
      return const Center(
        child: Icon(Icons.error, color: Colors.red, size: 30),
      );
    }

    // Load image if not in cache
    if (!_isLoading && !widget.memoryManager.isCached(widget.path)) {
      _loadImage();
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[300],
      child: _isLoading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : const Center(
              child: Icon(Icons.image, size: 30, color: Colors.grey),
            ),
    );
  }

  Future<void> _loadImage() async {
    if (_isLoading || !mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final imageData = await widget.loadingQueue.loadImage(
        widget.path,
        () => widget.mediaManager.getImagePreview(widget.path),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }
}

// Cached Video Thumbnail Widget
class _CachedVideoThumbnail extends StatefulWidget {
  final String path;
  final MediaManager mediaManager;
  final MemoryManager memoryManager;
  final ImageLoadingQueue loadingQueue;

  const _CachedVideoThumbnail({
    required this.path,
    required this.mediaManager,
    required this.memoryManager,
    required this.loadingQueue,
  });

  @override
  State<_CachedVideoThumbnail> createState() => _CachedVideoThumbnailState();
}

class _CachedVideoThumbnailState extends State<_CachedVideoThumbnail> {
  bool _isLoading = false;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final cacheKey = '${widget.path}_thumb';

    // Check cache first
    final cachedData = widget.memoryManager.getCachedImage(cacheKey);
    if (cachedData != null) {
      return Stack(
        children: [
          Image.memory(
            cachedData,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          const Positioned(
            bottom: 4,
            right: 4,
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 20,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        ],
      );
    }

    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 20),
            Icon(Icons.video_file, size: 20),
          ],
        ),
      );
    }

    // Load thumbnail if not in cache
    if (!_isLoading && !widget.memoryManager.isCached(cacheKey)) {
      _loadThumbnail();
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[300],
      child: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(height: 4),
                  Icon(Icons.video_file, size: 16),
                ],
              ),
            )
          : const Center(
              child: Icon(Icons.video_file, size: 30, color: Colors.grey),
            ),
    );
  }

  Future<void> _loadThumbnail() async {
    if (_isLoading || !mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final cacheKey = '${widget.path}_thumb';
      final thumbnailData = await widget.loadingQueue.loadImage(
        cacheKey,
        () => widget.mediaManager.getVideoThumbnail(widget.path),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }
}
