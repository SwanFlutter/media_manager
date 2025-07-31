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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _checkPermission();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final hasPermission = await _mediaManager.requestStoragePermission();
    setState(() {
      _hasPermission = hasPermission;
    });
    if (hasPermission) {
      _loadDirectories();
    }
  }

  Future<void> _loadDirectories() async {
    try {
      final directories = await _mediaManager.getDirectories();
      setState(() {
        _directories = directories;
      });
    } catch (e) {
      debugPrint('Error loading directories: $e');
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
  List<dynamic> _mediaItems = [];
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
      if (widget.mediaType == MediaType.audio) {
        final items = await widget.mediaManager.getAllAudio();
        setState(() {
          _mediaItems = items;
          _isLoading = false;
        });
      } else {
        List<String> mediaPaths;
        switch (widget.mediaType) {
          case MediaType.image:
            mediaPaths = await widget.mediaManager.getAllImages();
            break;
          case MediaType.video:
            mediaPaths = await widget.mediaManager.getAllVideos();
            break;
          case MediaType.document:
            mediaPaths = await widget.mediaManager.getAllDocuments();
            break;
          case MediaType.zip:
            mediaPaths = await widget.mediaManager.getAllZipFiles();
            break;
          default:
            mediaPaths = [];
        }
        setState(() {
          _mediaItems = mediaPaths;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('MediaTab error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_getMediaTypeTitle()),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMedia),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaItems.isEmpty
          ? Center(child: Text('No ${_getMediaTypeTitle()} found'))
          : widget.mediaType == MediaType.image
          ? _buildImageGrid()
          : widget.mediaType == MediaType.video
          ? _buildVideoGrid()
          : _buildMediaList(),
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
      itemCount: _mediaItems.length,
      itemBuilder: (context, index) {
        final path = _mediaItems[index] as String;
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
      itemCount: _mediaItems.length,
      itemBuilder: (context, index) {
        final path = _mediaItems[index] as String;
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
            future: widget.mediaManager.getVideoThumbnail(path),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Image.memory(snapshot.data!, fit: BoxFit.cover),
                      const Positioned(
                        bottom: 8,
                        right: 8,
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 32,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Icon(Icons.videocam, size: 30)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMediaList() {
    if (widget.mediaType == MediaType.audio) {
      return ListView.builder(
        itemCount: _mediaItems.length,
        itemBuilder: (context, index) {
          final item = _mediaItems[index] as Map<String, dynamic>;
          final path = item['path'] as String;
          final fileName = path.split('/').last;
          final cover = item['cover'] as Uint8List?;
          return ListTile(
            leading: cover != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      cover,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.audio_file),
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
    } else {
      return ListView.builder(
        itemCount: _mediaItems.length,
        itemBuilder: (context, index) {
          final path = _mediaItems[index] as String;
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
