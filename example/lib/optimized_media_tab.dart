// ignore_for_file: unreachable_switch_default

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_manager/media_manager.dart';

import 'memory_manager.dart';

/// A paginated, infinite-scroll tab that displays media items of [mediaType].
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
  static const _pageSize = 60;

  final List<MediaItem> _items = [];
  final ScrollController _scroll = ScrollController();

  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _initialised = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNext());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadNext();
    }
  }

  bool get _hasMore => _items.length < _total;

  Future<void> _loadNext() async {
    if (_loading || (!_hasMore && _initialised)) return;
    setState(() => _loading = true);

    try {
      if (!_initialised) {
        _total = await widget.mediaManager.getMediaCount(
          type: widget.mediaType,
        );
        _initialised = true;
      }
      if (!_hasMore) {
        setState(() => _loading = false);
        return;
      }

      final page = await widget.mediaManager.getMediaPage(
        type: widget.mediaType,
        page: _page,
        pageSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          _items.addAll(page);
          _page++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    _items.clear();
    _page = 0;
    _total = 0;
    _initialised = false;
    await _loadNext();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _Header(
          title: _title,
          shown: _items.length,
          total: _total,
          loading: _loading,
          onRefresh: _refresh,
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (!_initialised && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_typeIcon, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No $_title found',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    final isGrid =
        widget.mediaType == MediaType.image ||
        widget.mediaType == MediaType.video;

    if (isGrid) return _buildGrid();
    if (widget.mediaType == MediaType.audio) return _buildAudioList();
    return _buildDocumentList();
  }

  Widget _buildGrid() {
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: _items.length + (_hasMore || _loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final item = _items[i];
        return _ThumbnailTile(item: item, mediaManager: widget.mediaManager);
      },
    );
  }

  Widget _buildAudioList() {
    return ListView.builder(
      controller: _scroll,
      itemCount: _items.length + (_hasMore || _loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final item = _items[i];
        final ext = _extOfPath(item.name);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.purple.shade100,
            child: Icon(
              Icons.music_note,
              color: Colors.purple.shade700,
              size: 20,
            ),
          ),
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '$ext • ${_formatSize(item.size)} • ${_formatDuration(item.duration)}',
            style: const TextStyle(fontSize: 11),
          ),
        );
      },
    );
  }

  Widget _buildDocumentList() {
    return ListView.builder(
      controller: _scroll,
      itemCount: _items.length + (_hasMore || _loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final item = _items[i];
        final display = _displayName(item.name, item.uri);
        final ext = _extFrom(item.name, item.uri, item.mimeType);
        final typeName = _docTypeName(ext, item.mimeType);
        final color = _docColor(ext, item.mimeType);
        final icon = _docIcon(ext, item.mimeType);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(height: 1),
                  Text(
                    ext.isNotEmpty ? ext.toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '$typeName • ${_formatSize(item.size)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _displayName(String name, String uri) {
    if (name.isNotEmpty) return name;
    final seg = uri
        .split(RegExp(r'[/\\]'))
        .lastWhere((s) => s.isNotEmpty, orElse: () => '');
    final decoded = Uri.decodeComponent(seg);
    return decoded.isNotEmpty ? decoded : 'Unknown File';
  }

  static String _extFrom(String name, String uri, String? mime) {
    var e = _extOfPath(name);
    if (e.isNotEmpty) return e;
    e = _extOfPath(uri.split('?').first);
    if (e.isNotEmpty) return e;
    if (mime != null && mime.contains('/')) {
      final sub = mime.split('/').last.split('+').first.toLowerCase();
      const mimeToExt = <String, String>{
        'jpeg': 'jpg',
        'png': 'png',
        'gif': 'gif',
        'webp': 'webp',
        'bmp': 'bmp',
        'tiff': 'tiff',
        'pdf': 'pdf',
        'msword': 'doc',
        'vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
        'vnd.ms-excel': 'xls',
        'vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
        'vnd.ms-powerpoint': 'ppt',
        'vnd.openxmlformats-officedocument.presentationml.presentation': 'pptx',
        'plain': 'txt',
        'html': 'html',
        'xml': 'xml',
        'json': 'json',
        'zip': 'zip',
        'x-rar-compressed': 'rar',
        'vnd.rar': 'rar',
        'x-7z-compressed': '7z',
        'x-tar': 'tar',
        'gzip': 'gz',
        'mpeg': 'mp3',
        'ogg': 'ogg',
        'flac': 'flac',
        'wav': 'wav',
        'mp4': 'mp4',
        'quicktime': 'mov',
        'x-sqlite3': 'sqlite',
        'sqlite3': 'sqlite',
      };
      final mapped = mimeToExt[sub];
      if (mapped != null) return mapped;
      if (sub.length <= 8 && RegExp(r'^[a-z0-9]+$').hasMatch(sub)) return sub;
    }
    return '';
  }

  static String _extOfPath(String path) {
    final clean = path.split('?').first.split('#').first;
    final i = clean.lastIndexOf('.');
    if (i < 0 || i == clean.length - 1) return '';
    final e = clean.substring(i + 1).toLowerCase();
    return (e.length <= 10 && RegExp(r'^[a-z0-9]+$').hasMatch(e)) ? e : '';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '';
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final h = m ~/ 60;
    if (h > 0) return '${h}h ${m % 60}m';
    if (m > 0) return '${m}m ${s % 60}s';
    return '${s}s';
  }

  String get _title {
    switch (widget.mediaType) {
      case MediaType.image:
        return 'Images';
      case MediaType.video:
        return 'Videos';
      case MediaType.audio:
        return 'Audio';
      case MediaType.document:
        return 'Documents';
      case MediaType.any:
        return 'All Files';
      default:
        return 'Files';
    }
  }

  IconData get _typeIcon {
    switch (widget.mediaType) {
      case MediaType.image:
        return Icons.image;
      case MediaType.video:
        return Icons.video_file;
      case MediaType.audio:
        return Icons.audio_file;
      case MediaType.document:
        return Icons.insert_drive_file;
      case MediaType.any:
        return Icons.folder;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _docTypeName(String ext, String? mime) {
    const map = {
      'pdf': 'PDF Document',
      'doc': 'Word Document',
      'docx': 'Word Document',
      'docm': 'Word Macro Document',
      'dot': 'Word Template',
      'dotx': 'Word Template',
      'txt': 'Plain Text',
      'rtf': 'Rich Text',
      'odt': 'OpenDocument Text',
      'pages': 'Apple Pages',
      'wpd': 'WordPerfect',
      'md': 'Markdown',
      'markdown': 'Markdown',
      'tex': 'LaTeX',
      'xls': 'Excel Spreadsheet',
      'xlsx': 'Excel Spreadsheet',
      'xlsm': 'Excel Macro',
      'xlsb': 'Excel Binary',
      'ods': 'OpenDocument Spreadsheet',
      'numbers': 'Apple Numbers',
      'csv': 'CSV Spreadsheet',
      'ppt': 'PowerPoint',
      'pptx': 'PowerPoint',
      'pptm': 'PowerPoint Macro',
      'odp': 'OpenDocument Presentation',
      'key': 'Apple Keynote',
      'epub': 'eBook (EPUB)',
      'mobi': 'eBook (MOBI)',
      'azw': 'Kindle eBook',
      'fb2': 'FictionBook',
      'djvu': 'DjVu Document',
      'xps': 'XPS Document',
      'zip': 'ZIP Archive',
      'rar': 'RAR Archive',
      '7z': '7-Zip Archive',
      'tar': 'TAR Archive',
      'gz': 'GZip Archive',
      'bz2': 'BZip2 Archive',
      'dart': 'Dart Source',
      'py': 'Python Source',
      'java': 'Java Source',
      'kt': 'Kotlin Source',
      'swift': 'Swift Source',
      'js': 'JavaScript',
      'ts': 'TypeScript',
      'html': 'HTML',
      'css': 'CSS',
      'json': 'JSON',
      'xml': 'XML',
      'yaml': 'YAML',
      'yml': 'YAML',
      'cpp': 'C++ Source',
      'c': 'C Source',
      'h': 'C/C++ Header',
      'cs': 'C# Source',
      'go': 'Go Source',
      'rs': 'Rust Source',
      'rb': 'Ruby Source',
      'php': 'PHP Source',
      'sql': 'SQL Script',
      'ini': 'INI Config',
      'cfg': 'Config File',
      'conf': 'Config File',
      'toml': 'TOML Config',
      'log': 'Log File',
      'db': 'Database',
      'sqlite': 'SQLite Database',
      'sqlite3': 'SQLite Database',
      'mdb': 'Access Database',
    };
    return map[ext] ??
        (ext.isNotEmpty
            ? '${ext.toUpperCase()} File'
            : (mime != null ? mime.split('/').last.toUpperCase() : 'File'));
  }

  Color _docColor(String ext, String? mime) {
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
      case 'docm':
      case 'dot':
      case 'dotx':
      case 'pages':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
      case 'xlsm':
      case 'ods':
      case 'numbers':
      case 'csv':
        return Colors.green;
      case 'ppt':
      case 'pptx':
      case 'pptm':
      case 'odp':
      case 'key':
        return Colors.orange;
      case 'txt':
      case 'rtf':
      case 'md':
      case 'markdown':
      case 'log':
      case 'tex':
        return Colors.blueGrey;
      case 'epub':
      case 'mobi':
      case 'azw':
      case 'fb2':
      case 'djvu':
        return Colors.teal;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
        return Colors.brown;
      case 'db':
      case 'sqlite':
      case 'sqlite3':
      case 'mdb':
        return Colors.indigo;
      case 'dart':
      case 'py':
      case 'java':
      case 'kt':
      case 'swift':
      case 'go':
      case 'rs':
      case 'cpp':
      case 'c':
      case 'cs':
      case 'rb':
      case 'php':
      case 'js':
      case 'ts':
        return Colors.purple;
      case 'html':
      case 'css':
        return Colors.deepOrange;
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
      case 'toml':
      case 'ini':
      case 'cfg':
      case 'conf':
        return Colors.cyan.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _docIcon(String ext, String? mime) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
      case 'docm':
      case 'dot':
      case 'dotx':
      case 'pages':
      case 'wpd':
      case 'rtf':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'xlsm':
      case 'xlsb':
      case 'ods':
      case 'numbers':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
      case 'pptm':
      case 'odp':
      case 'key':
        return Icons.slideshow;
      case 'txt':
      case 'md':
      case 'markdown':
      case 'tex':
      case 'log':
        return Icons.article;
      case 'epub':
      case 'mobi':
      case 'azw':
      case 'fb2':
      case 'djvu':
        return Icons.menu_book;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
      case 'bz2':
        return Icons.folder_zip;
      case 'db':
      case 'sqlite':
      case 'sqlite3':
      case 'mdb':
        return Icons.storage;
      case 'html':
      case 'css':
        return Icons.web;
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
      case 'toml':
        return Icons.data_object;
      case 'sql':
        return Icons.table_rows;
      default:
        return Icons.insert_drive_file;
    }
  }
}

// ── Thumbnail tile ──────────────────────────────────────────────────────────
class _ThumbnailTile extends StatefulWidget {
  final MediaItem item;
  final MediaManager mediaManager;

  const _ThumbnailTile({required this.item, required this.mediaManager});

  @override
  State<_ThumbnailTile> createState() => _ThumbnailTileState();
}

class _ThumbnailTileState extends State<_ThumbnailTile> {
  String? _thumbPath;
  bool _loading = false;
  bool _error = false;

  String get _cacheKey => '${widget.item.uri}|${widget.item.dateModified}';

  @override
  void initState() {
    super.initState();
    final cached = ThumbnailPathCache().get(_cacheKey);
    if (cached != null) {
      _thumbPath = cached;
    } else {
      _fetchThumb();
    }
  }

  Future<void> _fetchThumb() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final path = await ThumbnailQueue().request(
        _cacheKey,
        () => widget.mediaManager.getThumbnail(
          uriOrPath: widget.item.uri,
          width: 200,
          dateModified: widget.item.dateModified,
          kind: widget.item.kind,
        ),
      );
      if (mounted) {
        setState(() {
          _thumbPath = path;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(_thumbPath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _placeholder(),
        ),
      );
    }
    if (_error) return _placeholder(icon: Icons.broken_image);
    return _placeholder(loading: _loading);
  }

  Widget _placeholder({bool loading = false, IconData icon = Icons.image}) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: Colors.grey, size: 28),
      ),
    );
  }
}

// ── Header row ──────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String title;
  final int shown;
  final int total;
  final bool loading;
  final VoidCallback onRefresh;

  const _Header({
    required this.title,
    required this.shown,
    required this.total,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title ($total)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (shown < total)
                  Text(
                    'Showing $shown of $total',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                  tooltip: 'Refresh',
                ),
        ],
      ),
    );
  }
}
