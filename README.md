# Media Manager Plugin

[![pub package](https://img.shields.io/pub/v/media_manager.svg)](https://pub.dev/packages/media_manager)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS-blue.svg)](https://github.com/SwanFlutter/media_manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin for managing media files and directories across multiple platforms. This plugin provides a comprehensive set of features for browsing directories, accessing media files, and managing file operations.

## ✨ Features

- 📁 **Directory browsing and navigation**  
  Browse through device storage with full directory tree support

- 🔍 **File type detection and categorization**  
  Automatically detect and categorize files by their type and extension

- 🖼️ **Image preview with caching**  
  Generate and cache thumbnails for quick image previews

- 🗂️ **Media file organization**  
  Easily access files by type:
    - 🖼️ Images
    - 🎥 Videos
    - 🎵 Audio
    - 📄 Documents
    - 🗜️ Archives (ZIP, RAR, etc.)

- 📏 **File size formatting**  
  Human-readable file sizes (e.g., 2.5 MB instead of 2621440 bytes)

- 🔐 **Storage permission handling**  
  Simplified permission management for accessing device storage

- 📱 **Cross-platform support**  
  Works seamlessly across:
    - 🤖 Android
    - 🍏 iOS
    - 💻 macOS








![20250410_232749](https://github.com/user-attachments/assets/a4f4b66b-dfcb-42da-9236-1c1decd6fd52)





## Installation

Add this to your package's `pubspec.yaml` file:

```yaml

dependencies:
  media_manager: ^0.0.2

```

## Usage

### Initialize the Plugin

```dart

import 'package:media_manager/media_manager.dart';

```

```dart

final mediaManager = MediaManager();

```

### Get Platform Version

```dart
// Get the platform version
void checkPlatformVersion() async {
  String? version = await mediaManager.getPlatformVersion();
  print('Platform version: $version');
}
```

### Request Storage Permission

```dart
// Request storage permission (Android/iOS only)
void checkAndRequestPermission() async {
  bool hasPermission = await mediaManager.requestStoragePermission();
  if (hasPermission) {
    print('Permission granted, proceeding with operations');
    // Continue with media operations
  } else {
    print('Permission denied, showing error message');
    // Show error or request again
  }
}

```

### Get Directories

```dart

// Get list of directories
void listDirectories() async {
  List<Map<String, dynamic>> dirs = await mediaManager.getDirectories();
  for (var dir in dirs) {
    print('Directory: ${dir['name']}');
    print('Path: ${dir['path']}');
  }
}

```

### Get Directory Contents

```dart
// Get contents of a specific directory
void showDirectoryContents() async {
  String path = '/storage/emulated/0/Downloads';
  var contents = await mediaManager.getDirectoryContents(path);
  for (var item in contents) {
    print('Name: ${item['name']}');
    print('Type: ${item['type']}');
    print('Size: ${item['readableSize']}');
    print('Is Directory: ${item['isDirectory']}');
    print('Extension: ${item['extension']}');
  }
}
```

### Get Image Preview

```dart
// Get image preview with caching
Widget buildImagePreview(String imagePath) {
  return FutureBuilder<Uint8List?>(
    future: mediaManager.getImagePreview(imagePath),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done && 
          snapshot.data != null) {
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
        );
      } else {
        return CircularProgressIndicator();
      }
    },
  );
}
```

### Clear Image Cache

```dart
// Clear the image preview cache
void clearCache() async {
  bool success = await mediaManager.clearImageCache();
  if (success) {
    print('Cache cleared successfully');
  } else {
    print('Failed to clear cache');
  }
}
```

### Get All Images

```dart
// Get all images from device storage
void displayAllImages() async {
  List<String> images = await mediaManager.getAllImages();
  print('Found ${images.length} images');
  for (String path in images) {
    print('Image path: $path');
    // Use paths to display images in your UI
  }
}
```

### Get All Videos

```dart
// Get all videos from device storage
void listAllVideos() async {
  List<String> videos = await mediaManager.getAllVideos();
  print('Found ${videos.length} videos');
  for (String videoPath in videos.take(5)) {
    print('Video: $videoPath');
    // Process video files
  }
}
```

### Get All Audio Files

```dart
// Get all audio files from device storage
void scanAudioLibrary() async {
  List<String> audioFiles = await mediaManager.getAllAudio();
  print('Your audio library contains ${audioFiles.length} files');
  
  // Create audio player for the first file if available
  if (audioFiles.isNotEmpty) {
    String firstAudioPath = audioFiles.first;
    print('First audio file: $firstAudioPath');
    // Initialize audio player with this path
  }
}
```

### Get All Documents

```dart
// Get all document files from device storage
void organizeDocuments() async {
  List<String> docs = await mediaManager.getAllDocuments();
  
  // Group documents by extension
  Map<String, List<String>> docsByType = {};
  
  for (String path in docs) {
    String ext = path.split('.').last.toLowerCase();
    if (!docsByType.containsKey(ext)) {
      docsByType[ext] = [];
    }
    docsByType[ext]!.add(path);
  }
  
  // Print document statistics
  docsByType.forEach((ext, files) {
    print('Found ${files.length} .$ext files');
  });
}
```

### Get All Zip Files

```dart
// Get all zip/archive files from device storage
void findArchives() async {
  List<String> archives = await mediaManager.getAllZipFiles();
  print('Found ${archives.length} archive files');
  
  // Calculate total size of all archives
  for (String archivePath in archives) {
    print('Archive: $archivePath');
    // You could get file size here and sum them
  }
  
  // Show dialog to user if many large archives are found
  if (archives.length > 10) {
    print('Consider cleaning up your archive files to save space');
  }
}
```

## Complete Example

Here's a complete example showing how to use the plugin in a Flutter app:

```dart
import 'package:flutter/material.dart';
import 'package:media_manager/media_manager.dart';

class MediaManagerScreen extends StatefulWidget {
  @override
  _MediaManagerScreenState createState() => _MediaManagerScreenState();
}

class _MediaManagerScreenState extends State<MediaManagerScreen> {
  final _mediaManager = MediaManager();
  bool _hasPermission = false;
  List<Map<String, dynamic>> _directories = [];

  @override
  void initState() {
    super.initState();
    _checkPermission();
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
      print('Error loading directories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Storage permission is required'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkPermission,
                child: Text('Request Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Media Manager Demo'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDirectories,
          ),
        ],
      ),
      body: _directories.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _directories.length,
              itemBuilder: (context, index) {
                final directory = _directories[index];
                return ListTile(
                  leading: Icon(Icons.folder),
                  title: Text(directory['name']),
                  subtitle: Text(directory['path']),
                );
              },
            ),
    );
  }
}
```

## Supported File Types

### Images
- jpg, jpeg, png, gif, bmp, webp, tiff, ico, svg, heif, heic

### Videos
- mp4, mov, mkv, avi, wmv, flv, webm, m4v, 3gp, f4v, ogv

### Audio
- mp3, wav, m4a, ogg, flac, aac, wma, aiff, opus

### Documents
- pdf, doc, docx, txt, rtf, odt, xls, xlsx, ppt, pptx, csv, html, xml, json

### Archives
- zip, rar, tar, gz, 7z, bz2, xz, lzma, cab, iso, dmg

## Platform Specific Notes

### Android
- Requires `READ_EXTERNAL_STORAGE` permission
- Supports all file types and operations
- Full access to external storage

### iOS
- Uses Photos framework for media access
- Limited to user's media library
- Some file operations may be restricted
- Requires photo library access permission

### macOS
- Uses AppKit/NSImage for image processing
- Uses FileManager for file operations
- Full access to file system
- No storage permission required
- Supports all file types and operations
- Uses macOS-specific path handling
- Supports sandboxed and non-sandboxed environments
- Handles macOS-specific file attributes and metadata

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

@SwanFlutter
SwanFlutter SwanFlutter1993
@rezash76
rezash76 Reza Sharifi


## License

This project is licensed under the MIT License - see the LICENSE file for details.
