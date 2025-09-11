import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

/// Memory manager for efficient image caching with LRU eviction
class MemoryManager {
  static const int _maxCacheSize = 100; // Maximum number of cached items
  static const int _maxMemoryUsage = 50 * 1024 * 1024; // 50MB in bytes

  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  int _currentMemoryUsage = 0;

  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  /// Get cached image data
  Uint8List? getCachedImage(String path) {
    if (_cache.containsKey(path)) {
      // Move to end (most recently used)
      final data = _cache.remove(path)!;
      _cache[path] = data;
      return data;
    }
    return null;
  }

  /// Cache image data with LRU eviction
  void cacheImage(String path, Uint8List data) {
    // Remove existing entry if present
    if (_cache.containsKey(path)) {
      _currentMemoryUsage -= _cache[path]!.length;
      _cache.remove(path);
    }

    // Check memory limit
    _currentMemoryUsage += data.length;

    // Evict old items if necessary
    while ((_cache.length >= _maxCacheSize ||
            _currentMemoryUsage > _maxMemoryUsage) &&
        _cache.isNotEmpty) {
      final oldestKey = _cache.keys.first;
      final oldestData = _cache.remove(oldestKey)!;
      _currentMemoryUsage -= oldestData.length;
    }

    // Add new item
    _cache[path] = data;
  }

  /// Check if image is cached
  bool isCached(String path) {
    return _cache.containsKey(path);
  }

  /// Clear all cached images
  void clearCache() {
    _cache.clear();
    _currentMemoryUsage = 0;
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedItems': _cache.length,
      'memoryUsage': _currentMemoryUsage,
      'memoryUsageMB': (_currentMemoryUsage / (1024 * 1024)).toStringAsFixed(2),
      'maxItems': _maxCacheSize,
      'maxMemoryMB': (_maxMemoryUsage / (1024 * 1024)).toStringAsFixed(2),
    };
  }

  /// Remove specific item from cache
  void removeFromCache(String path) {
    if (_cache.containsKey(path)) {
      _currentMemoryUsage -= _cache[path]!.length;
      _cache.remove(path);
    }
  }

  /// Preload images for better performance
  Future<void> preloadImages(
    List<String> paths,
    Future<Uint8List?> Function(String) loader,
  ) async {
    for (final path in paths.take(10)) {
      // Preload only first 10 items
      if (!isCached(path)) {
        try {
          final data = await loader(path);
          if (data != null) {
            cacheImage(path, data);
          }
        } catch (e) {
          // Ignore preload errors
        }
      }
    }
  }
}

/// Image loading queue to prevent too many simultaneous loads
class ImageLoadingQueue {
  static const int _maxConcurrentLoads = 3;

  final Set<String> _loadingPaths = {};
  final Queue<_LoadRequest> _queue = Queue();
  int _activeLoads = 0;

  static final ImageLoadingQueue _instance = ImageLoadingQueue._internal();
  factory ImageLoadingQueue() => _instance;
  ImageLoadingQueue._internal();

  /// Add image to loading queue
  Future<Uint8List?> loadImage(
    String path,
    Future<Uint8List?> Function() loader,
  ) async {
    // Check if already loading
    if (_loadingPaths.contains(path)) {
      // Wait for existing load to complete
      while (_loadingPaths.contains(path)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return MemoryManager().getCachedImage(path);
    }

    final completer = Completer<Uint8List?>();
    final request = _LoadRequest(path, loader, completer);

    _queue.add(request);
    _processQueue();

    return completer.future;
  }

  void _processQueue() {
    while (_queue.isNotEmpty && _activeLoads < _maxConcurrentLoads) {
      final request = _queue.removeFirst();
      _activeLoads++;
      _loadingPaths.add(request.path);

      _loadImageInternal(request);
    }
  }

  Future<void> _loadImageInternal(_LoadRequest request) async {
    try {
      final data = await request.loader();
      if (data != null) {
        MemoryManager().cacheImage(request.path, data);
      }
      request.completer.complete(data);
    } catch (e) {
      request.completer.completeError(e);
    } finally {
      _activeLoads--;
      _loadingPaths.remove(request.path);
      _processQueue();
    }
  }
}

class _LoadRequest {
  final String path;
  final Future<Uint8List?> Function() loader;
  final Completer<Uint8List?> completer;

  _LoadRequest(this.path, this.loader, this.completer);
}
