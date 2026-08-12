/// Lightweight helpers for running CPU-bound Dart work off the UI thread.
///
/// NOTE: Flutter MethodChannel calls **must** happen on the platform thread
/// (main isolate).  Therefore this file only provides utilities for
/// post-processing data that was already fetched from the platform, not for
/// making platform calls from a secondary isolate.
library;

import 'dart:isolate';

import 'models/media_item.dart';

// ─── Compute helpers ─────────────────────────────────────────────────────────

/// Parses a raw list of maps (returned by the method channel) into
/// [MediaItem] objects inside a background isolate so the UI thread
/// stays responsive when the page is large.
///
/// Usage:
/// ```dart
/// final raw = await methodChannel.invokeMethod<List<dynamic>>('getMediaPage', ...);
/// final items = await parseMediaItems(raw ?? []);
/// ```
Future<List<MediaItem>> parseMediaItems(List<dynamic> raw) async {
  if (raw.isEmpty) return const [];
  // For small pages (<= 200 items) stay on main isolate to avoid spawn overhead.
  if (raw.length <= 200) {
    return _doParse(raw);
  }
  return Isolate.run(() => _doParse(raw));
}

List<MediaItem> _doParse(List<dynamic> raw) => raw
    .map((e) => MediaItem.fromMap(Map<String, dynamic>.from(e as Map)))
    .toList(growable: false);
