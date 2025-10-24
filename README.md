
# Media Manager Plugin

[![pub package](https://img.shields.io/pub/v/media_manager.svg)](https://pub.dev/packages/media_manager)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS-blue.svg)](https://github.com/SwanFlutter/media_manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B.svg?logo=flutter)](https://flutter.dev)

A comprehensive Flutter plugin for managing media files and directories across multiple platforms. This plugin provides powerful features for browsing directories, accessing media files, generating thumbnails, and managing file operations with high performance isolate support.

## Features Overview

- **Directory Management**: Browse and navigate through device storage with comprehensive directory tree support
- **Media File Access**: Access images, videos, audio files, documents, and archives with type detection
- **Thumbnail Generation**: Generate and cache image previews and video thumbnails efficiently
- **Album Art Extraction**: Extract album artwork from audio files
- **Custom Format Support**: Search for files by custom extensions (APK, code files, configs, etc.)
- **Performance Optimization**: Built-in isolate support for heavy operations to prevent UI freezing
- **Cross-Platform**: Full support for Android, iOS, and macOS
- **Permission Management**: Simplified storage permission handling

<img width="386" height="869" alt="media_managerPNG" src="https://github.com/user-attachments/assets/bdec60df-446c-4b70-9b2b-66047fcd92bf" />

## Platform Compatibility

| Platform | Min Version | Max Tested | Status |
|----------|-------------|------------|--------|
| **Android** | 5.0 (API 21) | 16.0 (API 36) | ✅ Fully Supported |
| **iOS** | 12.0 | 18.0 | ✅ Fully Supported |
| **macOS** | 11.0 (Big Sur) | 15.0 (Sequoia) | ✅ Fully Supported |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  media_manager: ^0.1.0
```

Run the installation command:

```bash
flutter pub get
```

### Platform Setup

#### Android Setup

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Basic permissions -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" tools:ignore="ScopedStorage" />

<!-- Android 13+ granular permissions -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />

<!-- For comprehensive file access -->
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" tools:ignore="ScopedStorage" />
```

#### iOS Setup

Add to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photo library to manage media files.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs access to photo library to save media files.</string>
```

#### macOS Setup

Add to `macos/Runner/Info.plist`:

```xml
<key>NSDocumentsFolderUsageDescription</key>
<string>This app needs access to Documents folder to manage files.</string>
<key>NSDownloadsFolderUsageDescription</key>
<string>This app needs access to Downloads folder to manage files.</string>
```

## API Reference & Usage Examples

### Basic Setup

```dart
import 'package:media_manager/media_manager.dart';

class MediaService {
  static final _mediaManager = MediaManager();
  
  // Access the media manager instance
  static MediaManager get instance => _mediaManager;
}

// Or use MediaManager directly
final mediaManager = MediaManager();
```

### 1. Platform Information

Get platform version information:

```dart
Future<void> getPlatformInfo() async {
  try {
    final version = await MediaManager().getPlatformVersion();
    // Or using the service wrapper
    // final version = await MediaService.instance.getPlatformVersion();
    print('Platform version: $version');
  } catch (e) {
    print('Error getting platform version: $e');
  }
```

### 2. Storage Permission Management

Request and check storage permissions:

```dart
Future<bool> checkStoragePermission() async {
  try {
    final hasPermission = await MediaManager().requestStoragePermission();
    // Or using the service wrapper
    // final hasPermission = await MediaService.instance.requestStoragePermission();
    
    if (hasPermission) {
      print('✅ Storage permission granted');
      return true;
    } else {
      print('❌ Storage permission denied');
      return false;
    }
  } catch (e) {
    print('Error requesting permission: $e');
    return false;
  }
}

// Usage in widget
class PermissionCheck extends StatefulWidget {
  @override
  _PermissionCheckState createState() => _PermissionCheckState();
}

class _PermissionCheckState extends State<PermissionCheck> {
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final hasPermission = await checkStoragePermission();
    setState(() {
      _hasPermission = hasPermission;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _hasPermission 
        ? MyAppContent() 
        : PermissionRequestScreen(onPermissionGranted: _checkPermission);
  }
}
```

### 3. Directory Operations

#### Get Available Directories

```dart
Future<void> loadDirectories() async {
  try {
    final directories = await MediaManager().getDirectories();
    // Or using the service wrapper
    // final directories = await MediaService.instance.getDirectories();
    
    print('Found ${directories.length} directories:');
    for (final dir in directories) {
      print('📁 ${dir['name']}: ${dir['path']}');
    }
  } catch (e) {
    print('Error loading directories: $e');
  }
}
```

#### Get Directory Contents

```dart
Future<void> exploreDirectory(String path) async {
  try {
    final contents = await MediaManager().getDirectoryContents(path);
    // Or using the service wrapper
    // final contents = await MediaService.instance.getDirectoryContents(path);
    
    print('\n📂 Contents of $path:');
    for (final item in contents) {
      final isDir = item['isDirectory'] as bool;
      final icon = isDir ? '📁' : '📄';
      final size = isDir ? '' : ' (${item['readableSize']})';
      
      print('$icon ${item['name']}$size');
    }
  } catch (e) {
    print('Error reading directory: $e');
  }
}

// Usage example
void main() async {
  await loadDirectories();
  await exploreDirectory('/storage/emulated/0/Download');
}
```

### 4. Image Operations

#### Get All Images

```dart
Future<List<String>> getAllDeviceImages() async {
  try {
    final images = await MediaManager().getAllImages();
    // Or using the service wrapper
    // final images = await MediaService.instance.getAllImages();
    print('📸 Found ${images.length} images');
    
    // Group by extension
    final imagesByType = <String, int>{};
    for (final path in images) {
      final ext = path.split('.').last.toLowerCase();
      imagesByType[ext] = (imagesByType[ext] ?? 0) + 1;
    }
    
    print('Image formats:');
    imagesByType.forEach((ext, count) {
      print('  $ext: $count files');
    });
    
    return images;
  } catch (e) {
    print('Error loading images: $e');
    return [];
  }
}
```

#### Generate Image Previews

```dart
import 'dart:typed_data';

Future<Uint8List?> getImageThumbnail(String imagePath) async {
  try {
    final thumbnail = await MediaManager().getImagePreview(imagePath);
    // Or using the service wrapper
    // final thumbnail = await MediaService.instance.getImagePreview(imagePath);
    
    if (thumbnail != null) {
      print('✅ Generated thumbnail for ${imagePath.split('/').last}');
      return thumbnail;
    } else {
      print('❌ Failed to generate thumbnail');
      return null;
    }
  } catch (e) {
    print('Error generating thumbnail: $e');
    return null;
  }
}

// Widget usage
class ImageThumbnail extends StatelessWidget {
  final String imagePath;
  
  const ImageThumbnail({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: getImageThumbnail(imagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          );
        }
        
        return Icon(Icons.image, size: 50);
      },
    );
  }
}
```

#### Clear Image Cache

```dart
Future<void> clearImageCache() async {
  try {
    await MediaManager().clearImageCache();
    // Or using the service wrapper
    // await MediaService.instance.clearImageCache();
    print('🧹 Image cache cleared successfully');
  } catch (e) {
    print('Error clearing cache: $e');
  }
}
```

### 5. Video Operations

#### Get All Videos

```dart
Future<List<String>> getAllDeviceVideos() async {
  try {
    final videos = await MediaManager().getAllVideos();
    // Or using the service wrapper
    // final videos = await MediaService.instance.getAllVideos();
    print('🎥 Found ${videos.length} videos');
    
    // Show first 5 videos
    for (final video in videos.take(5)) {
      final fileName = video.split('/').last;
      print('  📹 $fileName');
    }
    
    return videos;
  } catch (e) {
    print('Error loading videos: $e');
    return [];
  }
}
```

#### Generate Video Thumbnails

```dart
Future<Uint8List?> getVideoPreview(String videoPath) async {
  try {
    final thumbnail = await MediaManager().getVideoThumbnail(videoPath);
    // Or using the service wrapper
    // final thumbnail = await MediaService.instance.getVideoThumbnail(videoPath);
    
    if (thumbnail != null) {
      print('✅ Generated video thumbnail for ${videoPath.split('/').last}');
      return thumbnail;
    } else {
      print('❌ Failed to generate video thumbnail');
      return null;
    }
  } catch (e) {
    print('Error generating video thumbnail: $e');
    return null;
  }
}

// Widget usage
class VideoThumbnail extends StatelessWidget {
  final String videoPath;
  
  const VideoThumbnail({Key? key, required this.videoPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: getVideoPreview(videoPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 150,
            height: 100,
            color: Colors.grey[300],
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return Stack(
            children: [
              Image.memory(
                snapshot.data!,
                width: 150,
                height: 100,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.play_circle, color: Colors.white, size: 24),
              ),
            ],
          );
        }
        
        return Container(
          width: 150,
          height: 100,
          color: Colors.grey[400],
          child: Icon(Icons.video_file, size: 40),
        );
      },
    );
  }
}
```

### 6. Audio Operations

#### Get All Audio Files

```dart
Future<List<String>> getAllDeviceAudio() async {
  try {
    final audioFiles = await MediaManager().getAllAudio();
    // Or using the service wrapper
    // final audioFiles = await MediaService.instance.getAllAudio();
    print('🎵 Found ${audioFiles.length} audio files');
    
    // Create a simple audio library structure
    final audioLibrary = <String, List<String>>{};
    
    for (final audioPath in audioFiles) {
      final fileName = audioPath.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      
      audioLibrary.putIfAbsent(extension, () => []).add(audioPath);
    }
    
    print('Audio library by format:');
    audioLibrary.forEach((format, files) {
      print('  $format: ${files.length} files');
    });
    
    return audioFiles;
  } catch (e) {
    print('Error loading audio files: $e');
    return [];
  }
}
```

#### Extract Album Art

```dart
Future<Uint8List?> getAlbumArtwork(String audioPath) async {
  try {
    final albumArt = await MediaManager().getAudioThumbnail(audioPath);
    // Or using the service wrapper
    // final albumArt = await MediaService.instance.getAudioThumbnail(audioPath);
    
    if (albumArt != null) {
      print('🎨 Extracted album art from ${audioPath.split('/').last}');
      return albumArt;
    } else {
      print('🎵 No album art found');
      return null;
    }
  } catch (e) {
    print('Error extracting album art: $e');
    return null;
  }
}

// Widget usage
class AlbumArtWidget extends StatelessWidget {
  final String audioPath;
  
  const AlbumArtWidget({Key? key, required this.audioPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: getAlbumArtwork(audioPath),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: MemoryImage(snapshot.data!),
                fit: BoxFit.cover,
              ),
            ),
          );
        }
        
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.music_note, size: 40, color: Colors.grey[600]),
        );
      },
    );
  }
}
```

### 7. Document Operations

#### Get All Documents

```dart
Future<Map<String, List<String>>> getAllDocuments() async {
  try {
    final documents = await MediaManager().getAllDocuments();
    // Or using the service wrapper
    // final documents = await MediaService.instance.getAllDocuments();
    print('📄 Found ${documents.length} documents');
    
    // Organize documents by type
    final documentsByType = <String, List<String>>{};
    
    for (final docPath in documents) {
      final fileName = docPath.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();
      
      String category = getCategoryForExtension(extension);
      documentsByType.putIfAbsent(category, () => []).add(docPath);
    }
    
    print('Documents by category:');
    documentsByType.forEach((category, files) {
      print('  $category: ${files.length} files');
    });
    
    return documentsByType;
  } catch (e) {
    print('Error loading documents: $e');
    return {};
  }
}

String getCategoryForExtension(String extension) {
  switch (extension) {
    case 'pdf':
      return 'PDF Documents';
    case 'doc':
    case 'docx':
      return 'Word Documents';
    case 'xls':
    case 'xlsx':
      return 'Excel Spreadsheets';
    case 'ppt':
    case 'pptx':
      return 'PowerPoint Presentations';
    case 'txt':
    case 'rtf':
      return 'Text Files';
    default:
      return 'Other Documents';
  }
}
```

### 8. Archive Operations

#### Get All Archive Files

```dart
Future<void> manageArchives() async {
  try {
    final archives = await MediaManager().getAllZipFiles();
    // Or using the service wrapper
    // final archives = await MediaService.instance.getAllZipFiles();
    
    print('📦 Found ${archives.length} archive files');
    
    if (archives.length > 10) {
      print('💡 Tip: You have many archive files. Consider cleaning up old archives to save space.');
    }
    
    // Show archive statistics
    final archiveStats = <String, int>{};
    for (final archivePath in archives) {
      final extension = archivePath.split('.').last.toLowerCase();
      archiveStats[extension] = (archiveStats[extension] ?? 0) + 1;
    }
    
    print('Archive types:');
    archiveStats.forEach((ext, count) {
      print('  .$ext: $count files');
    });
    
  } catch (e) {
    print('Error loading archives: $e');
  }
}
```

### 9. Custom File Format Search

#### Search Files by Format

```dart
Future<void> findCustomFiles() async {
  try {
    // Find Android APK files
    final apkFiles = await MediaManager()
        .getAllFilesByFormat(['apk']);
    print('📱 Found ${apkFiles.length} APK files');
    
    // Find source code files
    final codeFiles = await MediaManager()
        .getAllFilesByFormat(['dart', 'java', 'kt', 'swift', 'py']);
    print('💻 Found ${codeFiles.length} source code files');
    
    // Find configuration files
    final configFiles = await MediaManager()
        .getAllFilesByFormat(['json', 'xml', 'yaml', 'ini']);
    print('⚙️ Found ${configFiles.length} configuration files');
    
    // Find database files
    final dbFiles = await MediaManager()
        .getAllFilesByFormat(['db', 'sqlite', 'sql']);
    print('🗃️ Found ${dbFiles.length} database files');
    
    // Find additional archives
    final rarFiles = await MediaManager()
        .getAllFilesByFormat(['rar', '7z', 'tar', 'gz']);
    print('📦 Found ${rarFiles.length} additional archive files');
    
  } catch (e) {
    print('Error searching custom files: $e');
  }
}

// Advanced search example
Future<Map<String, List<String>>> searchAllCustomFormats() async {
  final results = <String, List<String>>{};
  
  final categories = {
    'Apps': ['apk', 'ipa', 'exe', 'msi'],
    'Code': ['dart', 'java', 'kt', 'swift', 'py', 'js', 'ts'],
    'Config': ['json', 'xml', 'yaml', 'ini', 'cfg'],
    'Database': ['db', 'sqlite', 'sql', 'mdb'],
    'Archives': ['rar', '7z', 'tar', 'gz', 'bz2'],
  };
  
  try {
    for (final entry in categories.entries) {
      final files = await MediaManager().getAllFilesByFormat(entry.value);
      results[entry.key] = files;
      print('${entry.key}: ${files.length} files');
    }
    
    final totalFiles = results.values.fold(0, (sum, list) => sum + list.length);
    print('\n📊 Total custom files found: $totalFiles');
    
  } catch (e) {
    print('Error in comprehensive search: $e');
  }
  
  return results;
}

### 10. Performance Management & Isolate Usage

#### Isolate Configuration

The MediaManager plugin includes built-in isolate support to prevent UI freezing during heavy file operations. This is especially important when scanning large numbers of media files.

```dart
class MediaManagerConfig {
  // Enable/disable isolates for heavy operations
  static void configurePerformance({bool useIsolates = true}) {
    MediaManager.setIsolateUsage(useIsolates);
    print('🏃 Isolates ${useIsolates ? 'enabled' : 'disabled'} for heavy operations');
  }
  
  // Clean up resources
  static void cleanup() {
    MediaManager.disposeIsolates();
    print('🧹 Isolate resources cleaned up');
  }
}

// Usage in app lifecycle
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MediaManagerConfig.configurePerformance(useIsolates: true);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MediaManagerConfig.cleanup();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      MediaManagerConfig.cleanup();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Manager Demo',
      home: MediaManagerDemo(),
    );
  }
}

#### Toggle Isolates in Runtime

You can provide users with the ability to toggle isolate usage for better performance control:

```dart
class MediaManagerScreen extends StatefulWidget {
  @override
  _MediaManagerScreenState createState() => _MediaManagerScreenState();
}

class _MediaManagerScreenState extends State<MediaManagerScreen> {
  final _mediaManager = MediaManager();
  // Or using the service wrapper
  // final _mediaManager = MediaService.instance;
  
  List<String> _images = [];
  List<String> _videos = [];
  List<String> _audioFiles = [];
  bool _isLoading = false;
  bool _isolatesEnabled = false;
  void _toggleIsolates() {
    setState(() {
      _isolatesEnabled = !_isolatesEnabled;
      MediaManager.setIsolateUsage(_isolatesEnabled);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isolatesEnabled 
          ? 'Isolates enabled - Better performance for large file operations'
          : 'Isolates disabled - Operations run on main thread'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  @override
  void dispose() {
    MediaManager.disposeIsolates(); // Clean up isolates
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Media Manager'),
        actions: [
          IconButton(
            icon: Icon(_isolatesEnabled ? Icons.speed : Icons.speed_outlined),
            onPressed: _toggleIsolates,
            tooltip: _isolatesEnabled ? 'Disable Isolates' : 'Enable Isolates',
          ),
        ],
      ),
      body: YourMediaContent(),
    );
  }
}
}
```

## Complete Usage Example

Here's a comprehensive example showing how to use multiple features together:

```dart
import 'package:flutter/material.dart';
import 'package:media_manager/media_manager.dart';

class MediaManagerDemo extends StatefulWidget {
  @override
  _MediaManagerDemoState createState() => _MediaManagerDemoState();
}

class _MediaManagerDemoState extends State<MediaManagerDemo> {
  final _mediaManager = MediaService.instance;
  bool _hasPermission = false;
  bool _isLoading = false;
  
  final Map<String, int> _mediaCounts = {};

  @override
  void initState() {
    super.initState();
    _initializeMediaManager();
  }

  Future<void> _initializeMediaManager() async {
    setState(() => _isLoading = true);
    
    // Request permissions
    _hasPermission = await _mediaManager.requestStoragePermission();
    
    if (_hasPermission) {
      await _loadMediaStatistics();
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadMediaStatistics() async {
    try {
      final results = await Future.wait([
        _mediaManager.getAllImages(),
        _mediaManager.getAllVideos(),
        _mediaManager.getAllAudio(),
        _mediaManager.getAllDocuments(),
        _mediaManager.getAllZipFiles(),
      ]);
      
      setState(() {
        _mediaCounts['Images'] = results[0].length;
        _mediaCounts['Videos'] = results[1].length;
        _mediaCounts['Audio'] = results[2].length;
        _mediaCounts['Documents'] = results[3].length;
        _mediaCounts['Archives'] = results[4].length;
      });
      
      print('📊 Media Statistics:');
      _mediaCounts.forEach((type, count) {
        print('  $type: $count files');
      });
      
    } catch (e) {
      print('Error loading media statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Media Manager Demo'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _hasPermission ? _loadMediaStatistics : null,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading media information...'),
          ],
        ),
      );
    }

    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Storage permission required'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeMediaManager,
              child: Text('Request Permission'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Media Library Overview',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _mediaCounts.length,
              itemBuilder: (context, index) {
                final entry = _mediaCounts.entries.elementAt(index);
                return _MediaTypeCard(
                  title: entry.key,
                  count: entry.value,
                  onTap: () => _navigateToMediaType(entry.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToMediaType(String mediaType) {
    // Navigate to specific media type screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaTypeScreen(mediaType: mediaType),
      ),
    );
  }
}

class _MediaTypeCard extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onTap;

  const _MediaTypeCard({
    Key? key,
    required this.title,
    required this.count,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIconForMediaType(title),
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '$count files',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForMediaType(String type) {
    switch (type) {
      case 'Images':
        return Icons.image;
      case 'Videos':
        return Icons.video_library;
      case 'Audio':
        return Icons.library_music;
      case 'Documents':
        return Icons.description;
      case 'Archives':
        return Icons.archive;
      default:
        return Icons.folder;
    }
  }
}

class MediaTypeScreen extends StatelessWidget {
  final String mediaType;

  const MediaTypeScreen({Key? key, required this.mediaType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$mediaType Files'),
      ),
      body: Center(
        child: Text('$mediaType file browser would go here'),
      ),
    );
  }
}

## Error Handling

The plugin provides comprehensive error handling:

```dart
try {
  final result = await MediaService.instance.getAllImages();
} catch (e) {
  if (e is PlatformException) {
    switch (e.code) {
      case 'PERMISSION_DENIED':
        print('❌ Storage permission denied');
        break;
      case 'DIRECTORY_ACCESS_ERROR':
        print('❌ Cannot access directory');
        break;
      case 'FILE_NOT_FOUND':
        print('❌ File not found');
        break;
      case 'INVALID_PATH':
        print('❌ Invalid file path');
        break;
      default:
        print('❌ Unknown error: ${e.message}');
    }
  } else {
    print('❌ Unexpected error: $e');
  }
}
```

## Supported File Types

### Images
`jpg`, `jpeg`, `png`, `gif`, `bmp`, `webp`, `tiff`, `ico`, `svg`, `heif`, `heic`

### Videos  
`mp4`, `mov`, `mkv`, `avi`, `wmv`, `flv`, `webm`, `m4v`, `3gp`, `f4v`, `ogv`

### Audio
`mp3`, `wav`, `m4a`, `ogg`, `flac`, `aac`, `wma`, `aiff`, `opus`

### Documents
`pdf`, `doc`, `docx`, `txt`, `rtf`, `odt`, `xls`, `xlsx`, `ppt`, `pptx`, `csv`, `html`, `xml`, `json`

### Archives
`zip`, `rar`, `tar`, `gz`, `7z`, `bz2`, `xz`, `lzma`, `cab`, `iso`, `dmg`

### Custom Formats
Any file extension can be searched using `getAllFilesByFormat(['extension'])`.

## Performance Tips

1. **Use Isolates**: Enable isolate usage for heavy operations to prevent UI blocking
2. **Cache Management**: Regularly clear image cache to manage memory usage
3. **Batch Operations**: Process files in batches rather than individually
4. **Permission Check**: Always check permissions before performing file operations
5. **Error Handling**: Implement proper error handling for all operations


## Error Handling

The plugin provides detailed error messages for common scenarios:

```dart
try {
  final directories = await mediaManager.getDirectories();
} catch (e) {
  if (e is PlatformException) {
    switch (e.code) {
      case 'DIRECTORY_ACCESS_ERROR':
        // Handle directory access error
        break;
      case 'INVALID_PATH':
        // Handle invalid path error
        break;
      case 'FILE_ACCESS_ERROR':
        // Handle file access error
        break;
      case 'IMAGE_LOAD_ERROR':
        // Handle image loading error
        break;
      case 'HOME_NOT_FOUND':
        // Handle home directory not found error
        break;
      default:
        // Handle other errors
    }
  }
}
```

## Contributors

<p align="left">
  <a href="https://github.com/SwanFlutter">
    <img src="https://contrib.rocks/image?repo=SwanFlutter/SwanFlutter" alt="SwanFlutter" style="vertical-align:middle;" />
    <span style="vertical-align:middle;">SwanFlutter</span>
  </a>
</p>

<li class="mb-2 d-flex">
      <a href="https://github.com/rezash76" class="mr-2" data-hovercard-type="user" data-hovercard-url="/users/rezash76/hovercard" data-octo-click="hovercard-link-click" data-octo-dimensions="link_type:self">
        <img src="https://avatars.githubusercontent.com/u/38264846?s=64&amp;v=4" alt="@rezash76" size="32" height="32" width="32" data-view-component="true" class="avatar circle">
      </a>
      <span data-view-component="true" class="flex-self-center min-width-0 css-truncate css-truncate-overflow width-fit flex-auto">
        <a href="https://github.com/rezash76" class="Link--primary no-underline flex-self-center">
          <strong><font style="vertical-align: inherit;"><font style="vertical-align: inherit;">rezash76 </font></font></strong>
          <span class="color-fg-muted"><font style="vertical-align: inherit;"><font style="vertical-align: inherit;">رضا شریفی</font></font></span>
        </a>
</span>    </li>



## License

This project is licensed under the MIT License - see the LICENSE file for details.
