// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_manager/media_manager.dart';

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

class MediaManagerScreen extends StatefulWidget {
  const MediaManagerScreen({super.key});

  @override
  State<MediaManagerScreen> createState() => _MediaManagerScreenState();
}

class _MediaManagerScreenState extends State<MediaManagerScreen>
    with SingleTickerProviderStateMixin {
  final _mediaManager = MediaManager();
  late TabController _tabController;
  bool _hasPermission = false;
  List<Map<String, dynamic>> _directories = [];
  List<Map<String, dynamic>> _directoryContents = [];
  String? _selectedDirectory;
  bool _isolatesEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _checkPermission();
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Dispose isolates when the app is closing
    MediaManager.disposeIsolates();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    debugPrint('Requesting storage permission...');
    final hasPermission = await _mediaManager.requestStoragePermission();
    debugPrint('Storage permission result: $hasPermission');
    setState(() {
      _hasPermission = hasPermission;
    });
    if (hasPermission) {
      debugPrint('Permission granted, loading directories...');
      _loadDirectories();
    } else {
      debugPrint('Permission denied! Cannot access media files.');
    }
  }

  Future<void> _loadDirectories() async {
    try {
      debugPrint('Loading directories...');
      final directories = await _mediaManager.getDirectories();
      debugPrint('Loaded ${directories.length} directories');
      setState(() {
        _directories = directories;
      });
    } catch (e) {
      debugPrint('Error loading directories: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading directories: $e')));
    }
  }

  Future<void> _loadDirectoryContents(String directoryPath) async {
    try {
      final contents = await _mediaManager.getDirectoryContents(directoryPath);
      setState(() {
        _directoryContents = contents;
        _selectedDirectory = directoryPath;
      });
    } catch (e) {
      debugPrint('Error loading directory contents: $e');
    }
  }

  // Add this method to navigate up one level
  void _navigateUp() {
    if (_selectedDirectory == null) return;

    final pathParts = _selectedDirectory!.split('/');
    // Remove the last part of the path
    if (pathParts.length > 2) {
      // Ensure we don't go above root
      pathParts.removeLast();
      final parentPath = pathParts.join('/');
      _loadDirectoryContents(parentPath);
    } else {
      // If we're already at the root level, go back to directory list
      setState(() {
        _selectedDirectory = null;
        _directoryContents = [];
      });
    }
  }

  void _toggleIsolates() {
    setState(() {
      _isolatesEnabled = !_isolatesEnabled;
      MediaManager.setIsolateUsage(_isolatesEnabled);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isolatesEnabled
              ? 'Isolates enabled - Better performance for large file operations'
              : 'Isolates disabled - Operations run on main thread',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearCache() async {
    await _mediaManager.clearImageCache();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Image cache cleared')));
  }

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
            icon: Icon(_isolatesEnabled ? Icons.speed : Icons.speed_outlined),
            onPressed: _toggleIsolates,
            tooltip: _isolatesEnabled ? 'Disable Isolates' : 'Enable Isolates',
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: _clearCache,
            tooltip: 'Clear Cache',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Explorer', icon: Icon(Icons.folder)),
            Tab(text: 'Images', icon: Icon(Icons.image)),
            Tab(text: 'Videos', icon: Icon(Icons.video_file)),
            Tab(text: 'Audio', icon: Icon(Icons.audio_file)),
            Tab(text: 'Documents', icon: Icon(Icons.insert_drive_file)),
            Tab(text: 'Archives', icon: Icon(Icons.archive)),
            Tab(text: 'Custom Files', icon: Icon(Icons.search)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDirectoriesTab(),
          MediaTab(mediaManager: _mediaManager, mediaType: MediaType.image),
          MediaTab(mediaManager: _mediaManager, mediaType: MediaType.video),
          MediaTab(mediaManager: _mediaManager, mediaType: MediaType.audio),
          MediaTab(mediaManager: _mediaManager, mediaType: MediaType.document),
          MediaTab(mediaManager: _mediaManager, mediaType: MediaType.zip),
          CustomFormatTab(mediaManager: _mediaManager),
        ],
      ),
    );
  }

  Widget _buildDirectoriesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _loadDirectories,
                  child: const Text('Refresh Directories'),
                ),
              ),
            ],
          ),
        ),
        if (_selectedDirectory != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateUp,
                ),
                Expanded(
                  child: Text(
                    'Directory: ${_selectedDirectory?.split('/').last}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedDirectory = null;
                      _directoryContents = [];
                    });
                  },
                ),
              ],
            ),
          ),
        Expanded(
          child: _selectedDirectory == null
              ? _directories.isEmpty
                    ? const Center(
                        child: Text(
                          'No directories found. Tap Refresh button.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _directories.length,
                        itemBuilder: (context, index) {
                          final directory = _directories[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.folder,
                                color: Colors.amber,
                              ),
                              title: Text(directory['name'] as String),
                              onTap: () => _loadDirectoryContents(
                                directory['path'] as String,
                              ),
                            ),
                          );
                        },
                      )
              : _directoryContents.isEmpty
              ? const Center(child: Text('Directory is empty'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _directoryContents.length,
                  itemBuilder: (context, index) {
                    final item = Map<String, dynamic>.from(
                      _directoryContents[index],
                    );
                    final name = item['name'] as String;
                    final isDirectory = item['isDirectory'] as bool;
                    final type = item['type'] as String;
                    final size = item['readableSize'] as String;
                    final extension = item['extension'] as String;

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          isDirectory ? Icons.folder : _getFileIcon(type),
                          color: isDirectory ? Colors.amber : Colors.blue,
                        ),
                        title: Text(name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_truncatePath(item['path'] as String)),
                            if (!isDirectory) Text('$size • $extension'),
                          ],
                        ),
                        onTap: () {
                          if (isDirectory) {
                            _loadDirectoryContents(item['path'] as String);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_file;
      case 'audio':
        return Icons.audio_file;
      case 'document':
        return Icons.description;
      case 'zip':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _truncatePath(String path) {
    if (path.length <= 40) return path;
    final parts = path.split('/');
    if (parts.length <= 2) return path;
    return '.../${parts[parts.length - 2]}/${parts.last}';
  }
}

enum MediaType { image, video, audio, document, zip }

// Tab for custom file formats
class CustomFormatTab extends StatefulWidget {
  final MediaManager mediaManager;

  const CustomFormatTab({super.key, required this.mediaManager});

  @override
  State<CustomFormatTab> createState() => _CustomFormatTabState();
}

class _CustomFormatTabState extends State<CustomFormatTab>
    with AutomaticKeepAliveClientMixin {
  List<String> _filePaths = [];
  bool _isLoading = false;
  String _selectedCategory = 'Apps';

  final Map<String, List<String>> _formatCategories = {
    'Apps': ['apk', 'ipa', 'exe', 'msi', 'deb', 'rpm'],
    'Code': ['dart', 'java', 'kt', 'swift', 'py', 'js', 'ts', 'cpp', 'c', 'h'],
    'Archives': ['rar', '7z', 'tar', 'gz', 'bz2', 'xz'],
    'Config': ['json', 'xml', 'yaml', 'yml', 'ini', 'cfg', 'conf'],
    'Database': ['db', 'sqlite', 'sql', 'mdb'],
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final formats = _formatCategories[_selectedCategory] ?? [];
      debugPrint(
        'بارگذاری فایل‌های $_selectedCategory با فرمت‌های: ${formats.join(", ")}',
      );

      final filePaths = await widget.mediaManager.getAllFilesByFormat(formats);
      debugPrint('پیدا شدن ${filePaths.length} فایل $_selectedCategory');

      setState(() {
        _filePaths = filePaths;
      });

      // نمایش پیام موفقیت برای کاربر
      if (mounted && filePaths.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${filePaths.length} فایل $_selectedCategory پیدا شد',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('خطا در بارگذاری فایل‌های $_selectedCategory: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در بارگذاری فایل‌های $_selectedCategory: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'تلاش مجدد',
              textColor: Colors.white,
              onPressed: _loadFiles,
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // Category selector
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select File Category:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                children: _formatCategories.keys.map((category) {
                  final isSelected = category == _selectedCategory;
                  return FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                        _loadFiles();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Formats: ${_formatCategories[_selectedCategory]?.join(", ") ?? ""}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),

        // Refresh button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadFiles,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _isLoading ? 'Loading...' : 'Refresh $_selectedCategory',
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // File list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filePaths.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No $_selectedCategory files found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Supported formats: ${_formatCategories[_selectedCategory]?.join(", ") ?? ""}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _filePaths.length,
                  itemBuilder: (context, index) {
                    final filePath = _filePaths[index];
                    final fileName = filePath.split('/').last;
                    final fileExtension = fileName
                        .split('.')
                        .last
                        .toLowerCase();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getColorForExtension(fileExtension),
                          child: Text(
                            fileExtension.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          fileName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          filePath,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          _getIconForCategory(_selectedCategory),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _getColorForExtension(String extension) {
    switch (extension) {
      case 'apk':
      case 'ipa':
        return Colors.green;
      case 'exe':
      case 'msi':
        return Colors.blue;
      case 'dart':
      case 'java':
      case 'kt':
        return Colors.orange;
      case 'py':
      case 'js':
      case 'ts':
        return Colors.purple;
      case 'rar':
      case '7z':
      case 'tar':
        return Colors.brown;
      case 'json':
      case 'xml':
      case 'yaml':
        return Colors.teal;
      case 'db':
      case 'sqlite':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Apps':
        return Icons.apps;
      case 'Code':
        return Icons.code;
      case 'Archives':
        return Icons.archive;
      case 'Config':
        return Icons.settings;
      case 'Database':
        return Icons.storage;
      default:
        return Icons.insert_drive_file;
    }
  }
}

// Tab for specific media types
class MediaTab extends StatefulWidget {
  final MediaManager mediaManager;
  final MediaType mediaType;

  const MediaTab({
    super.key,
    required this.mediaManager,
    required this.mediaType,
  });

  @override
  State<MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends State<MediaTab>
    with AutomaticKeepAliveClientMixin {
  List<String> _mediaPaths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<String> mediaPaths;
      switch (widget.mediaType) {
        case MediaType.image:
          mediaPaths = await widget.mediaManager.getAllImages();
          break;
        case MediaType.video:
          mediaPaths = await widget.mediaManager.getAllVideos();
          break;
        case MediaType.audio:
          debugPrint('Loading Audio files...');
          mediaPaths = await widget.mediaManager.getAllAudio();
          debugPrint('Loaded ${mediaPaths.length} Audio files');
          if (mediaPaths.isNotEmpty) {
            debugPrint('First Audio path: ${mediaPaths.first}');
            debugPrint('Sample audio paths:');
            for (int i = 0; i < mediaPaths.length && i < 3; i++) {
              debugPrint('  Audio $i: ${mediaPaths[i]}');
            }
          } else {
            debugPrint('No audio files found!');
          }
          break;
        case MediaType.document:
          debugPrint('Loading Document files...');
          try {
            mediaPaths = await widget.mediaManager.getAllDocuments();
            debugPrint('Loaded ${mediaPaths.length} Document files');
            if (mediaPaths.isNotEmpty) {
              debugPrint('First Document path: ${mediaPaths.first}');
              debugPrint('Sample document paths:');
              for (int i = 0; i < mediaPaths.length && i < 3; i++) {
                debugPrint('  Document $i: ${mediaPaths[i]}');
              }
            } else {
              debugPrint('No document files found!');
            }
          } catch (e) {
            debugPrint('Error loading documents: $e');
            debugPrint('Stack trace: ${StackTrace.current}');
            rethrow;
          }
          break;
        case MediaType.zip:
          debugPrint('Loading Archive/Zip files...');
          try {
            mediaPaths = await widget.mediaManager.getAllZipFiles();
            debugPrint('Loaded ${mediaPaths.length} Archive files');
            if (mediaPaths.isNotEmpty) {
              debugPrint('First Archive path: ${mediaPaths.first}');
              debugPrint('Sample archive paths:');
              for (int i = 0; i < mediaPaths.length && i < 3; i++) {
                debugPrint('  Archive $i: ${mediaPaths[i]}');
              }
            } else {
              debugPrint('No archive files found!');
            }
          } catch (e) {
            debugPrint('Error loading archives: $e');
            debugPrint('Stack trace: ${StackTrace.current}');
            rethrow;
          }
          break;
      }

      setState(() {
        _mediaPaths = mediaPaths;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading ${_getMediaTypeTitle()}: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ${_getMediaTypeTitle()}: $e')),
      );
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
              Text(
                _getMediaTypeTitle(),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
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
              ? const Center(child: CircularProgressIndicator())
              : _mediaPaths.isEmpty
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
              ? _buildImageGrid()
              : widget.mediaType == MediaType.video
              ? _buildVideoGrid()
              : widget.mediaType == MediaType.audio
              ? _buildAudioGrid()
              : _buildMediaList(),
        ),
      ],
    );
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

  Widget _buildImageGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _mediaPaths.length,
      itemBuilder: (context, index) {
        final path = _mediaPaths[index];
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
          child: FutureBuilder<Uint8List?>(
            future: widget.mediaManager.getImagePreview(path),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.red),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(snapshot.data!, fit: BoxFit.cover),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Icon(Icons.image, size: 30)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _mediaPaths.length,
      itemBuilder: (context, index) {
        final path = _mediaPaths[index];
        return GestureDetector(
          onTap: () {
            debugPrint('Tapped on video: $path');
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
          child: FutureBuilder<Uint8List?>(
            future: widget.mediaManager.getVideoThumbnail(path),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Icon(Icons.video_file, size: 20),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(height: 4),
                        Icon(Icons.video_file, size: 20),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data != null) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_file, size: 30),
                      SizedBox(height: 4),
                      Text('Video', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAudioGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _mediaPaths.length,
      itemBuilder: (context, index) {
        final path = _mediaPaths[index];
        final fileName = path.split('/').last;
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
          child: FutureBuilder<Uint8List?>(
            future: widget.mediaManager.getAudioThumbnail(path),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!, width: 1),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Icon(Icons.music_note, size: 20),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!, width: 1),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(height: 4),
                        Icon(Icons.music_note, size: 20),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data != null) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note, size: 40, color: Colors.blue[600]),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        fileName,
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMediaList() {
    return ListView.builder(
      itemCount: _mediaPaths.length,
      itemBuilder: (context, index) {
        final path = _mediaPaths[index];
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

// Screen for previewing media
class MediaPreviewScreen extends StatelessWidget {
  final String mediaPath;
  final MediaType mediaType;
  final MediaManager mediaManager;

  const MediaPreviewScreen({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    required this.mediaManager,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(mediaPath.split('/').last)),
      body: Center(child: _buildMediaPreview()),
    );
  }

  Widget _buildMediaPreview() {
    switch (mediaType) {
      case MediaType.image:
        return FutureBuilder<Uint8List?>(
          future: mediaManager.getImagePreview(mediaPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (snapshot.hasData && snapshot.data != null) {
              return InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Image.memory(snapshot.data!, fit: BoxFit.contain),
              );
            } else {
              return const Text('Image not available');
            }
          },
        );
      case MediaType.video:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_file, size: 100),
            const SizedBox(height: 20),
            Text(
              'Video: ${mediaPath.split('/').last}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Here you would typically implement video playback
                // For example, using the video_player package
              },
              child: const Text('Play Video'),
            ),
          ],
        );
      case MediaType.audio:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.audio_file, size: 100),
            const SizedBox(height: 20),
            Text(
              'Audio: ${mediaPath.split('/').last}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Here you would typically implement audio playback
                // For example, using the audioplayers package
              },
              child: const Text('Play Audio'),
            ),
          ],
        );
      case MediaType.document:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file, size: 100),
            const SizedBox(height: 20),
            Text(
              'Document: ${mediaPath.split('/').last}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Here you would typically implement document viewing
                // For example, using the flutter_pdfview package for PDFs
              },
              child: const Text('Open Document'),
            ),
          ],
        );
      case MediaType.zip:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.archive, size: 100),
            const SizedBox(height: 20),
            Text(
              'Archive: ${mediaPath.split('/').last}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Here you would typically implement archive extraction
                // or listing of contents
              },
              child: const Text('Extract Archive'),
            ),
          ],
        );
    }
  }
}
