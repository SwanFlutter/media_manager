// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:media_manager/media_manager.dart';

import 'optimized_media_tab.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Media Manager Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MediaManagerScreen(),
    );
  }
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class MediaManagerScreen extends StatefulWidget {
  const MediaManagerScreen({super.key});

  @override
  State<MediaManagerScreen> createState() => _MediaManagerScreenState();
}

class _MediaManagerScreenState extends State<MediaManagerScreen>
    with SingleTickerProviderStateMixin {
  final _mm = MediaManager();
  late TabController _tabs;

  bool _hasPermission = false;
  List<Map<String, String>> _directories = [];
  List<Map<String, dynamic>> _directoryContents = [];
  String? _selectedDirectory;
  int dirPage = 0;
  static const _dirPageSize = 200;
  bool _dirLoading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _checkPermission();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Permission ──────────────────────────────────────────────────────────

  Future<void> _checkPermission() async {
    final granted = await _mm.requestStoragePermission();
    setState(() => _hasPermission = granted);
    if (granted) _loadDirectories();
  }

  // ── Directories ─────────────────────────────────────────────────────────

  Future<void> _loadDirectories() async {
    try {
      final dirs = await _mm.getDirectories();
      setState(() => _directories = dirs);
    } catch (e) {
      _snack('Error loading directories: $e');
    }
  }

  Future<void> _loadDirectoryContents(String path, {int page = 0}) async {
    if (_dirLoading) return;
    setState(() => _dirLoading = true);
    try {
      final contents = await _mm.getDirectoryContents(
        path: path,
        page: page,
        pageSize: _dirPageSize,
      );
      setState(() {
        if (page == 0) {
          _directoryContents = contents;
          _selectedDirectory = path;
          dirPage = 0;
        } else {
          _directoryContents.addAll(contents);
          dirPage = page;
        }
      });
    } catch (e) {
      _snack('Error: $e');
    } finally {
      setState(() => _dirLoading = false);
    }
  }

  void _navigateUp() {
    if (_selectedDirectory == null) return;
    final parts = _selectedDirectory!.replaceAll('\\', '/').split('/');
    if (parts.length > 2) {
      parts.removeLast();
      _loadDirectoryContents(parts.join('/'));
    } else {
      setState(() {
        _selectedDirectory = null;
        _directoryContents = [];
      });
    }
  }

  // ── Cache clear ─────────────────────────────────────────────────────────

  Future<void> _clearCache() async {
    await _mm.clearThumbnailCache();
    _snack('Thumbnail cache cleared');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Storage permission is required'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkPermission,
                child: const Text('Request Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Manager Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: _clearCache,
            tooltip: 'Clear Thumbnail Cache',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Explorer', icon: Icon(Icons.folder)),
            Tab(text: 'Images', icon: Icon(Icons.image)),
            Tab(text: 'Videos', icon: Icon(Icons.video_file)),
            Tab(text: 'Audio', icon: Icon(Icons.audio_file)),
            Tab(text: 'Docs', icon: Icon(Icons.insert_drive_file)),
            Tab(text: 'Custom', icon: Icon(Icons.search)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildExplorerTab(),
          OptimizedMediaTab(mediaManager: _mm, mediaType: MediaType.image),
          OptimizedMediaTab(mediaManager: _mm, mediaType: MediaType.video),
          OptimizedMediaTab(mediaManager: _mm, mediaType: MediaType.audio),
          OptimizedMediaTab(mediaManager: _mm, mediaType: MediaType.document),
          _CustomFormatTab(mediaManager: _mm),
        ],
      ),
    );
  }

  // ── Explorer tab ─────────────────────────────────────────────────────────

  Widget _buildExplorerTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadDirectories,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Directories'),
                ),
              ),
            ],
          ),
        ),
        if (_selectedDirectory != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateUp,
                ),
                Expanded(
                  child: Text(
                    _selectedDirectory!.split(RegExp(r'[/\\]')).last,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _selectedDirectory = null;
                    _directoryContents = [];
                  }),
                ),
              ],
            ),
          ),
        Expanded(
          child: _selectedDirectory == null ? _dirList() : _contentList(),
        ),
      ],
    );
  }

  Widget _dirList() {
    if (_directories.isEmpty) {
      return const Center(child: Text('No directories found. Tap Refresh.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _directories.length,
      itemBuilder: (ctx, i) {
        final d = _directories[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.folder, color: Colors.amber),
            title: Text(d['name'] ?? ''),
            subtitle: Text(
              d['path'] ?? '',
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => _loadDirectoryContents(d['path']!),
          ),
        );
      },
    );
  }

  Widget _contentList() {
    if (_directoryContents.isEmpty && _dirLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_directoryContents.isEmpty) {
      return const Center(child: Text('Directory is empty'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _directoryContents.length,
      itemBuilder: (ctx, i) {
        final item = _directoryContents[i];
        final name = item['name'] as String;
        final isDir = item['isDirectory'] as bool;
        final ext = item['extension'] as String? ?? '';
        final size = item['size'] as int? ?? 0;

        return Card(
          child: ListTile(
            leading: Icon(
              isDir ? Icons.folder : _extIcon(ext),
              color: isDir ? Colors.amber : Colors.blue,
            ),
            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: isDir ? null : Text(_formatSize(size)),
            onTap: isDir
                ? () => _loadDirectoryContents(item['path'] as String)
                : null,
          ),
        );
      },
    );
  }

  IconData _extIcon(String ext) {
    const m = {
      'jpg': Icons.image,
      'jpeg': Icons.image,
      'png': Icons.image,
      'mp4': Icons.video_file,
      'mov': Icons.video_file,
      'mp3': Icons.audio_file,
      'flac': Icons.audio_file,
      'pdf': Icons.picture_as_pdf,
      'zip': Icons.folder_zip,
      'rar': Icons.folder_zip,
    };
    return m[ext] ?? Icons.insert_drive_file;
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── Custom format tab ───────────────────────────────────────────────────────

class _CustomFormatTab extends StatefulWidget {
  final MediaManager mediaManager;
  const _CustomFormatTab({required this.mediaManager});

  @override
  State<_CustomFormatTab> createState() => _CustomFormatTabState();
}

class _CustomFormatTabState extends State<_CustomFormatTab>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 100;

  final Map<String, List<String>> _categories = {
    'Apps': ['apk', 'ipa', 'exe', 'msi', 'deb', 'rpm'],
    'Code': ['dart', 'java', 'kt', 'swift', 'py', 'js', 'ts', 'cpp', 'c'],
    'Archives': ['rar', '7z', 'tar', 'gz', 'bz2', 'xz'],
    'Config': ['json', 'xml', 'yaml', 'yml', 'ini', 'cfg'],
    'Database': ['db', 'sqlite', 'sql', 'mdb'],
  };

  String _selected = 'Apps';
  List<MediaItem> _items = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!reset && _items.length >= _total && _total > 0) return;
    setState(() => _loading = true);

    try {
      final exts = _categories[_selected] ?? [];
      if (reset) {
        _total = await widget.mediaManager.getMediaCount(
          type: MediaType.any,
          extensions: exts,
        );
        _page = 0;
        _items = [];
      }
      final page = await widget.mediaManager.getMediaPage(
        type: MediaType.any,
        extensions: exts,
        page: _page,
        pageSize: _pageSize,
      );
      setState(() {
        _items.addAll(page);
        _page++;
      });
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Category chips
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Wrap(
            spacing: 8,
            children: _categories.keys.map((cat) {
              return FilterChip(
                label: Text(cat),
                selected: cat == _selected,
                onSelected: (_) {
                  setState(() => _selected = cat);
                  _load(reset: true);
                },
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Extensions: ${_categories[_selected]?.join(', ') ?? ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Text(
                '$_total files',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No $_selected files found',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      TextButton.icon(
                        onPressed: () => _load(reset: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _items.length + (_items.length < _total ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i >= _items.length) {
                      _load();
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final item = _items[i];
                    final ext = item.name.split('.').last.toLowerCase();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _colorFor(ext),
                          child: Text(
                            ext.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.uri,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _colorFor(String ext) {
    const m = {
      'apk': Colors.green,
      'ipa': Colors.green,
      'dart': Colors.blue,
      'kt': Colors.purple,
      'py': Colors.orange,
      'js': Colors.yellow,
      'json': Colors.teal,
      'xml': Colors.teal,
      'db': Colors.indigo,
      'sqlite': Colors.indigo,
      'rar': Colors.brown,
      '7z': Colors.brown,
    };
    return (m[ext] ?? Colors.grey) as Color;
  }
}
