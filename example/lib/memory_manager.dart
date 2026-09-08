import 'dart:async';
import 'dart:collection';

/// Simple LRU in-memory cache for thumbnail **paths** (strings).
///
/// Since thumbnails are now stored on disk and we only pass paths over the
/// channel, there is no large Uint8List to track.  This class maps
/// `uriOrPath` → `cachedJpegPath` so the UI avoids duplicate platform calls.
class ThumbnailPathCache {
  static const int _maxEntries = 500;

  final LinkedHashMap<String, String> _cache = LinkedHashMap();

  static final ThumbnailPathCache _instance = ThumbnailPathCache._internal();
  factory ThumbnailPathCache() => _instance;
  ThumbnailPathCache._internal();

  /// Returns the cached thumbnail path for [key], or `null` if absent.
  String? get(String key) {
    if (!_cache.containsKey(key)) return null;
    // Move to end (most-recently-used)
    final v = _cache.remove(key)!;
    _cache[key] = v;
    return v;
  }

  /// Stores [thumbPath] for [key], evicting the oldest entry when full.
  void put(String key, String thumbPath) {
    if (_cache.containsKey(key)) _cache.remove(key);
    if (_cache.length >= _maxEntries) _cache.remove(_cache.keys.first);
    _cache[key] = thumbPath;
  }

  bool contains(String key) => _cache.containsKey(key);

  void clear() => _cache.clear();

  int get length => _cache.length;
}

/// Limits concurrent thumbnail-generation calls to [maxConcurrent].
class ThumbnailQueue {
  final int maxConcurrent;

  final Map<String, List<Completer<String?>>> _waiters = {};
  final Set<String> _inFlight = {};
  final Queue<_ThumbnailRequest> _pending = Queue();
  int _active = 0;

  static final ThumbnailQueue _instance = ThumbnailQueue._internal();
  factory ThumbnailQueue() => _instance;
  ThumbnailQueue._internal() : maxConcurrent = 6;

  @visibleForTesting
  ThumbnailQueue.withConcurrency(this.maxConcurrent);

  /// Enqueues a thumbnail request and returns the resulting path.
  Future<String?> request(String key, Future<String?> Function() generate) {
    // If already cached, return immediately
    final cached = ThumbnailPathCache().get(key);
    if (cached != null) return Future.value(cached);

    // If already in-flight, attach a waiter instead of creating a duplicate job
    if (_inFlight.contains(key)) {
      final completer = Completer<String?>();
      _waiters.putIfAbsent(key, () => []).add(completer);
      return completer.future;
    }

    final completer = Completer<String?>();
    _pending.add(_ThumbnailRequest(key, generate, completer));
    _drain();
    return completer.future;
  }

  void _drain() {
    while (_pending.isNotEmpty && _active < maxConcurrent) {
      final req = _pending.removeFirst();
      _active++;
      _inFlight.add(req.key);
      _run(req);
    }
  }

  Future<void> _run(_ThumbnailRequest req) async {
    String? path;
    try {
      path = await req.generate();
      if (path != null) ThumbnailPathCache().put(req.key, path);
      req.completer.complete(path);
    } catch (e, st) {
      req.completer.completeError(e, st);
    } finally {
      _active--;
      _inFlight.remove(req.key);
      // Resolve all waiters for this key
      final waiters = _waiters.remove(req.key) ?? [];
      for (final w in waiters) {
        if (!w.isCompleted) w.complete(path);
      }
      _drain();
    }
  }
}

class _ThumbnailRequest {
  final String key;
  final Future<String?> Function() generate;
  final Completer<String?> completer;
  _ThumbnailRequest(this.key, this.generate, this.completer);
}

// Annotation stub so we don't need the meta package in the example.
const visibleForTesting = Object();
