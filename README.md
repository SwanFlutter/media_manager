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

- 🎬 **Video thumbnail generation**  
  Extract and display video thumbnails with play icon overlay

- 🎵 **Audio album art extraction**  
  Extract and display album artwork from audio files

- 🗂️ **Media file organization**  
  Easily access files by type:
    - 🖼️ Images
    - 🎥 Videos
    - 🎵 Audio
    - 📄 Documents
    - 🗜️ Archives (ZIP, RAR, etc.)
    - 📱 Custom formats (APK, code files, configs, etc.)

- 📏 **File size formatting**  
  Human-readable file sizes (e.g., 2.5 MB instead of 2621440 bytes)

- 🔐 **Storage permission handling**  
  Simplified permission management for accessing device storage

- 📱 **Cross-platform support**  
  Works seamlessly across:
    - 🤖 Android
    - 🍏 iOS
    - 💻 macOS



## 🔧 Platform Compatibility

| Platform | Minimum Version | Latest Tested | Status |
|----------|----------------|---------------|--------|
| **Android** | 5.0 (API 21) | 16.0 (API 36) | ✅ Fully Supported |
| **iOS** | 12.0 | 18.0 | ✅ Fully Supported |
| **macOS** | 11.0 (Big Sur) | 15.0 (Sequoia) | ✅ Fully Supported |

### Android Version Support Details
- **Android 5.0 - 9.0 (API 21-28)**: Legacy storage access
- **Android 10 (API 29)**: Scoped storage with compatibility mode
- **Android 11+ (API 30+)**: Full scoped storage with `MANAGE_EXTERNAL_STORAGE`
- **Android 13+ (API 33+)**: Granular media permissions
- **Android 14+ (API 34+)**: Enhanced privacy with partial access
- **Android 15+ (API 35+)**: Latest features and optimizations
- **Android 16 (API 36)**: Future-ready compatibility with enhanced media access

### iOS Version Support Details
- **iOS 12.0 - 13.6**: Basic photo library access
- **iOS 14.0+**: Enhanced privacy with limited photo access
- **iOS 15.0+**: Improved performance and security
- **iOS 16.0+**: Advanced media management features
- **iOS 17.0+**: Latest privacy enhancements and performance improvements
- **iOS 18.0**: Cutting-edge compatibility with latest Apple features

### macOS Version Support Details
- **macOS 11.0 (Big Sur)**: Modern file system APIs
- **macOS 12.0 (Monterey)**: Enhanced security features
- **macOS 13.0 (Ventura)**: Improved performance
- **macOS 14.0 (Sonoma)**: Advanced file management
- **macOS 15.0 (Sequoia)**: Latest features and optimizations



<img width="386" height="869" alt="media_managerPNG" src="https://github.com/user-attachments/assets/bdec60df-446c-4b70-9b2b-66047fcd92bf" />



## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  media_manager: ^0.0.4
```

Then run:

```bash
flutter pub get
```

### Platform Setup

#### 🤖 Android Setup

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Required permissions -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" tools:ignore="ScopedStorage" />

<!-- For Android 13 (API 33) and above -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />

<!-- For comprehensive file access (optional) -->
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" tools:ignore="ScopedStorage" />
```

**Minimum SDK Requirements:**
- `minSdkVersion`: 21 (Android 5.0)
- `compileSdkVersion`: 36 or higher (Android 16)
- `targetSdkVersion`: 36 or higher (Android 16)
- Supports up to **Android 16** (API 36)

**For Android 14+ (API 34+) enhanced permissions:**
```xml
<!-- Enhanced media permissions for Android 14+ -->
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
<uses-permission android:name="android.permission.ACCESS_MEDIA_LOCATION" />
```

**For Android 16+ (API 36+) future permissions:**
```xml
<!-- Future enhanced permissions for Android 16+ -->
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
<uses-permission android:name="android.permission.ACCESS_MEDIA_LOCATION" />
```

#### 🍏 iOS Setup

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photo library to manage media files.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs access to photo library to save media files.</string>
<key>NSCameraUsageDescription</key>
<string>This app needs access to camera to capture photos and videos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to microphone to record audio.</string>
```

**Minimum Requirements:**
- iOS 12.0 or higher (supports up to **iOS 18**)
- Xcode 15.0 or higher
- Swift 5.9 or higher

**For iOS 14+ enhanced privacy:**
```xml
<key>NSPhotoLibraryLimitedUsageDescription</key>
<string>This app needs limited access to photo library to manage selected media files.</string>
```

#### 💻 macOS Setup

Add the following to your `macos/Runner/Info.plist`:

```xml
<key>NSDocumentsFolderUsageDescription</key>
<string>This app needs access to Documents folder to manage files.</string>
<key>NSDownloadsFolderUsageDescription</key>
<string>This app needs access to Downloads folder to manage files.</string>
<key>NSRemovableVolumesUsageDescription</key>
<string>This app needs access to removable volumes to manage files.</string>
```

For full file system access, add to your `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.downloads.read-write</key>
<true/>
```

**Minimum Requirements:**
- macOS 11.0 (Big Sur) or higher (supports up to **macOS 15 Sequoia**)
- Xcode 15.0 or higher for development
- Swift 5.9 or higher

### 🟦 Flutter SDK Compatibility
- **Flutter 3.0+**: Full support with latest features
- **Flutter 3.10+**: Enhanced performance and stability
- **Flutter 3.16+**: Material 3 design and latest widgets
- **Flutter 3.19+**: Improved platform integration
- **Flutter 3.24+**: Latest stable release compatibility
- **Dart 3.0+**: Modern language features and null safety
- **Dart 3.5+**: Latest performance optimizations

## 📚 API Reference & Examples

### Basic Setup

```dart
import 'package:media_manager/media_manager.dart';

// Initialize the plugin
final mediaManager = MediaManager();
```

### 1. 🎯 Platform Version

Get information about the current platform:

```dart
class PlatformInfoWidget extends StatefulWidget {
  @override
  _PlatformInfoWidgetState createState() => _PlatformInfoWidgetState();
}

class _PlatformInfoWidgetState extends State<PlatformInfoWidget> {
  String? platformVersion;
  
  @override
  void initState() {
    super.initState();
    _getPlatformVersion();
  }
  
  Future<void> _getPlatformVersion() async {
    try {
      final version = await mediaManager.getPlatformVersion();
      setState(() {
        platformVersion = version;
      });
    } catch (e) {
      print('Error getting platform version: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 48),
            SizedBox(height: 8),
            Text(
              'Platform Version',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(platformVersion ?? 'Loading...'),
          ],
        ),
      ),
    );
  }
}
```

### 2. 🔐 Storage Permission

Request and handle storage permissions:

```dart
class PermissionManager extends StatefulWidget {
  final Widget child;
  
  const PermissionManager({Key? key, required this.child}) : super(key: key);
  
  @override
  _PermissionManagerState createState() => _PermissionManagerState();
}

class _PermissionManagerState extends State<PermissionManager> {
  bool? _hasPermission;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _checkPermission();
  }
  
  Future<void> _checkPermission() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final hasPermission = await mediaManager.requestStoragePermission();
      setState(() {
        _hasPermission = hasPermission;
        _isLoading = false;
      });
      
      if (hasPermission) {
        _showSnackBar('Permission granted successfully!', Colors.green);
      } else {
        _showSnackBar('Permission denied. Some features may not work.', Colors.red);
      }
    } catch (e) {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
      _showSnackBar('Error requesting permission: $e', Colors.red);
    }
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Requesting storage permission...'),
            ],
          ),
        ),
      );
    }
    
    if (_hasPermission == false) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storage, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Storage Permission Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This app needs storage permission to access your files.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _checkPermission,
                icon: Icon(Icons.security),
                label: Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }
    
    return widget.child;
  }
}
```

### 3. 📁 Directory Browser

Browse and navigate through directories:

```dart
class DirectoryBrowser extends StatefulWidget {
  @override
  _DirectoryBrowserState createState() => _DirectoryBrowserState();
}

class _DirectoryBrowserState extends State<DirectoryBrowser> {
  List<Map<String, dynamic>> _directories = [];
  List<Map<String, dynamic>> _currentContents = [];
  String? _currentPath;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadDirectories();
  }
  
  Future<void> _loadDirectories() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final directories = await mediaManager.getDirectories();
      setState(() {
        _directories = directories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load directories: $e');
    }
  }
  
  Future<void> _loadDirectoryContents(String path) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final contents = await mediaManager.getDirectoryContents(path);
      setState(() {
        _currentContents = contents;
        _currentPath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load directory contents: $e');
    }
  }
  
  void _navigateBack() {
    setState(() {
      _currentPath = null;
      _currentContents = [];
    });
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  Widget _buildFileIcon(Map<String, dynamic> item) {
    final isDirectory = item['isDirectory'] as bool;
    final type = item['type'] as String;
    
    if (isDirectory) {
      return Icon(Icons.folder, color: Colors.amber, size: 40);
    }
    
    switch (type) {
      case 'image':
        return Icon(Icons.image, color: Colors.blue, size: 40);
      case 'video':
        return Icon(Icons.video_file, color: Colors.red, size: 40);
      case 'audio':
        return Icon(Icons.audio_file, color: Colors.green, size: 40);
      case 'document':
        return Icon(Icons.description, color: Colors.orange, size: 40);
      case 'zip':
        return Icon(Icons.archive, color: Colors.purple, size: 40);
      default:
        return Icon(Icons.insert_drive_file, color: Colors.grey, size: 40);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(16),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Row(
            children: [
              if (_currentPath != null) ..[
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: _navigateBack,
                ),
                SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  _currentPath?.split('/').last ?? 'Directories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {
                  if (_currentPath != null) {
                    _loadDirectoryContents(_currentPath!);
                  } else {
                    _loadDirectories();
                  }
                },
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: _currentPath == null
              ? _buildDirectoriesList()
              : _buildDirectoryContents(),
        ),
      ],
    );
  }
  
  Widget _buildDirectoriesList() {
    if (_directories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No directories found'),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadDirectories,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _directories.length,
      itemBuilder: (context, index) {
        final directory = _directories[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(Icons.folder, color: Colors.amber, size: 40),
            title: Text(
              directory['name'] as String,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              directory['path'] as String,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _loadDirectoryContents(directory['path'] as String),
          ),
        );
      },
    );
  }
  
  Widget _buildDirectoryContents() {
    if (_currentContents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Directory is empty'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _currentContents.length,
      itemBuilder: (context, index) {
        final item = _currentContents[index];
        final isDirectory = item['isDirectory'] as bool;
        
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: _buildFileIcon(item),
            title: Text(
              item['name'] as String,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['path'] as String,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isDirectory)
                  Text(
                    '${item['readableSize']} • ${item['extension']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
              ],
            ),
            trailing: isDirectory 
                ? Icon(Icons.arrow_forward_ios, size: 16)
                : null,
            onTap: () {
              if (isDirectory) {
                _loadDirectoryContents(item['path'] as String);
              }
            },
          ),
        );
      },
    );
  }
}
```

### 4. 🖼️ Image Preview & Caching

Display image previews with efficient caching:

```dart
class ImagePreviewWidget extends StatefulWidget {
  final String imagePath;
  final double? width;
  final double? height;
  
  const ImagePreviewWidget({
    Key? key,
    required this.imagePath,
    this.width,
    this.height,
  }) : super(key: key);
  
  @override
  _ImagePreviewWidgetState createState() => _ImagePreviewWidgetState();
}

class _ImagePreviewWidgetState extends State<ImagePreviewWidget> {
  final mediaManager = MediaManager();
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? 200,
      height: widget.height ?? 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: mediaManager.getImagePreview(widget.imagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: Colors.grey[100],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Loading...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              );
            }
            
            if (snapshot.hasError) {
              return Container(
                color: Colors.red[50],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Error loading image',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            
            if (snapshot.hasData && snapshot.data != null) {
              return Stack(
                children: [
                  Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.image,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              );
            }
            
            return Container(
              color: Colors.grey[200],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, color: Colors.grey, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'No preview available',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Usage example:
class ImageGallery extends StatelessWidget {
  final List<String> imagePaths;
  
  const ImageGallery({Key? key, required this.imagePaths}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: imagePaths.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenImageView(
                  imagePath: imagePaths[index],
                ),
              ),
            );
          },
          child: ImagePreviewWidget(
            imagePath: imagePaths[index],
          ),
        );
      },
    );
  }
}
```

### 5. 🧹 Cache Management

Manage image cache efficiently:

```dart
class CacheManager extends StatefulWidget {
  @override
  _CacheManagerState createState() => _CacheManagerState();
}

class _CacheManagerState extends State<CacheManager> {
  final mediaManager = MediaManager();
  bool _isClearing = false;
  
  Future<void> _clearCache() async {
    setState(() {
      _isClearing = true;
    });
    
    try {
      await mediaManager.clearImageCache();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Cache cleared successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Failed to clear cache: $e'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isClearing = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cleaning_services, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Cache Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Clear cached image previews to free up memory and storage space.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isClearing ? null : _clearCache,
                icon: _isClearing 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.delete_sweep),
                label: Text(_isClearing ? 'Clearing...' : 'Clear Cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 6. 🇺️ Media File Management

#### Get All Images

```dart
class ImageManager extends StatefulWidget {
  @override
  _ImageManagerState createState() => _ImageManagerState();
}

class _ImageManagerState extends State<ImageManager> {
  final mediaManager = MediaManager();
  List<String> _imagePaths = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadImages();
  }
  
  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final images = await mediaManager.getAllImages();
      setState(() {
        _imagePaths = images;
        _isLoading = false;
      });
      
      print('Found ${images.length} images');
      
      // Show statistics
      _showImageStatistics(images);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showImageStatistics(List<String> images) {
    Map<String, int> extensionCount = {};
    
    for (String path in images) {
      String extension = path.split('.').last.toLowerCase();
      extensionCount[extension] = (extensionCount[extension] ?? 0) + 1;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Image Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Images: ${images.length}'),
            SizedBox(height: 8),
            Text('Formats:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...extensionCount.entries.map(
              (entry) => Text('  ${entry.key.toUpperCase()}: ${entry.value}'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading images...'),
          ],
        ),
      );
    }
    
    if (_imagePaths.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No images found'),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadImages,
              child: Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_imagePaths.length} Images',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.info),
                    onPressed: () => _showImageStatistics(_imagePaths),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: _loadImages,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _imagePaths.length,
            itemBuilder: (context, index) {
              return ImagePreviewWidget(
                imagePath: _imagePaths[index],
              );
            },
          ),
        ),
      ],
    );
  }
}
```

#### Get All Videos

```dart
class VideoManager extends StatefulWidget {
  @override
  _VideoManagerState createState() => _VideoManagerState();
}

class _VideoManagerState extends State<VideoManager> {
  final mediaManager = MediaManager();
  List<String> _videoPaths = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadVideos();
  }
  
  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final videos = await mediaManager.getAllVideos();
      setState(() {
        _videoPaths = videos;
        _isLoading = false;
      });
      
      print('Found ${videos.length} videos');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading videos: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: _videoPaths.length,
      itemBuilder: (context, index) {
        return VideoThumbnailWidget(
          videoPath: _videoPaths[index],
        );
      },
    );
  }
}

class VideoThumbnailWidget extends StatelessWidget {
  final String videoPath;
  
  const VideoThumbnailWidget({Key? key, required this.videoPath}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final mediaManager = MediaManager();
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: mediaManager.getVideoThumbnail(videoPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: Colors.grey[100],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Icon(Icons.video_file, size: 24),
                    ],
                  ),
                ),
              );
            }
            
            if (snapshot.hasData && snapshot.data != null) {
              return Stack(
                children: [
                  Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        videoPath.split('/').last.split('.').first,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              );
            }
            
            return Container(
              color: Colors.red[50],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(height: 8),
                    Text(
                      'Failed to load thumbnail',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

#### Get All Audio Files

```dart
class AudioManager extends StatefulWidget {
  @override
  _AudioManagerState createState() => _AudioManagerState();
}

class _AudioManagerState extends State<AudioManager> {
  final mediaManager = MediaManager();
  List<String> _audioPaths = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
  }
  
  Future<void> _loadAudioFiles() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final audioFiles = await mediaManager.getAllAudio();
      setState(() {
        _audioPaths = audioFiles;
        _isLoading = false;
      });
      
      print('Found ${audioFiles.length} audio files');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading audio files: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    return ListView.builder(
      itemCount: _audioPaths.length,
      itemBuilder: (context, index) {
        return AudioTileWidget(
          audioPath: _audioPaths[index],
        );
      },
    );
  }
}

class AudioTileWidget extends StatelessWidget {
  final String audioPath;
  
  const AudioTileWidget({Key? key, required this.audioPath}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final mediaManager = MediaManager();
    final fileName = audioPath.split('/').last;
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: FutureBuilder<Uint8List?>(
          future: mediaManager.getAudioThumbnail(audioPath),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Container(
                width: 50,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            }
            
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Icon(
                Icons.music_note,
                color: Colors.blue[600],
                size: 24,
              ),
            );
          },
        ),
        title: Text(
          fileName,
          style: TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          audioPath,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.play_arrow),
        onTap: () {
          // Handle audio playback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Playing: $fileName'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
```

### 7. 📄 Documents & Archives

#### Get All Documents

```dart
class DocumentManager extends StatefulWidget {
  @override
  _DocumentManagerState createState() => _DocumentManagerState();
}

class _DocumentManagerState extends State<DocumentManager> {
  final mediaManager = MediaManager();
  List<String> _documentPaths = [];
  Map<String, List<String>> _documentsByType = {};
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }
  
  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final documents = await mediaManager.getAllDocuments();
      _organizeDocumentsByType(documents);
      
      setState(() {
        _documentPaths = documents;
        _isLoading = false;
      });
      
      print('Found ${documents.length} documents');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading documents: $e')),
      );
    }
  }
  
  void _organizeDocumentsByType(List<String> documents) {
    _documentsByType.clear();
    
    for (String path in documents) {
      String extension = path.split('.').last.toLowerCase();
      String category = _getCategoryForExtension(extension);
      
      if (!_documentsByType.containsKey(category)) {
        _documentsByType[category] = [];
      }
      _documentsByType[category]!.add(path);
    }
  }
  
  String _getCategoryForExtension(String extension) {
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
      case 'html':
      case 'htm':
        return 'Web Documents';
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
        return 'Configuration Files';
      case 'md':
      case 'markdown':
        return 'Markdown Files';
      default:
        return 'Other Documents';
    }
  }
  
  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'PDF Documents':
        return Icons.picture_as_pdf;
      case 'Word Documents':
        return Icons.description;
      case 'Excel Spreadsheets':
        return Icons.table_chart;
      case 'PowerPoint Presentations':
        return Icons.slideshow;
      case 'Text Files':
        return Icons.text_snippet;
      case 'Web Documents':
        return Icons.web;
      case 'Configuration Files':
        return Icons.settings;
      case 'Markdown Files':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  Color _getColorForCategory(String category) {
    switch (category) {
      case 'PDF Documents':
        return Colors.red;
      case 'Word Documents':
        return Colors.blue;
      case 'Excel Spreadsheets':
        return Colors.green;
      case 'PowerPoint Presentations':
        return Colors.orange;
      case 'Text Files':
        return Colors.grey;
      case 'Web Documents':
        return Colors.purple;
      case 'Configuration Files':
        return Colors.teal;
      case 'Markdown Files':
        return Colors.indigo;
      default:
        return Colors.brown;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (_documentPaths.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No documents found'),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadDocuments,
              child: Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_documentPaths.length} Documents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _loadDocuments,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _documentsByType.keys.length,
            itemBuilder: (context, index) {
              String category = _documentsByType.keys.elementAt(index);
              List<String> files = _documentsByType[category]!;
              
              return ExpansionTile(
                leading: Icon(
                  _getIconForCategory(category),
                  color: _getColorForCategory(category),
                ),
                title: Text(category),
                subtitle: Text('${files.length} files'),
                children: files.map((path) {
                  String fileName = path.split('/').last;
                  return ListTile(
                    leading: Icon(
                      Icons.insert_drive_file,
                      color: _getColorForCategory(category),
                      size: 20,
                    ),
                    title: Text(
                      fileName,
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      path,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      // Handle document opening
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Opening: $fileName'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

#### Get All Archive Files

```dart
class ArchiveManager extends StatefulWidget {
  @override
  _ArchiveManagerState createState() => _ArchiveManagerState();
}

class _ArchiveManagerState extends State<ArchiveManager> {
  final mediaManager = MediaManager();
  List<String> _archivePaths = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadArchives();
  }
  
  Future<void> _loadArchives() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final archives = await mediaManager.getAllZipFiles();
      setState(() {
        _archivePaths = archives;
        _isLoading = false;
      });
      
      print('Found ${archives.length} archive files');
      
      if (archives.length > 10) {
        _showCleanupDialog();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading archives: $e')),
      );
    }
  }
  
  void _showCleanupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Storage Optimization'),
        content: Text(
          'You have ${_archivePaths.length} archive files. '
          'Consider cleaning up old archives to save storage space.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement cleanup functionality
            },
            child: Text('Review Files'),
          ),
        ],
      ),
    );
  }
  
  IconData _getArchiveIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'zip':
        return Icons.folder_zip;
      case 'rar':
        return Icons.archive;
      case '7z':
        return Icons.folder_special;
      case 'tar':
      case 'gz':
      case 'bz2':
        return Icons.compress;
      default:
        return Icons.archive;
    }
  }
  
  Color _getArchiveColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'zip':
        return Colors.blue;
      case 'rar':
        return Colors.purple;
      case '7z':
        return Colors.green;
      case 'tar':
      case 'gz':
      case 'bz2':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (_archivePaths.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No archive files found'),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadArchives,
              child: Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_archivePaths.length} Archives',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  if (_archivePaths.length > 5)
                    IconButton(
                      icon: Icon(Icons.cleaning_services, color: Colors.orange),
                      onPressed: _showCleanupDialog,
                    ),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: _loadArchives,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _archivePaths.length,
            itemBuilder: (context, index) {
              String path = _archivePaths[index];
              String fileName = path.split('/').last;
              String extension = fileName.split('.').last;
              
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getArchiveColor(extension).withOpacity(0.1),
                    child: Icon(
                      _getArchiveIcon(extension),
                      color: _getArchiveColor(extension),
                    ),
                  ),
                  title: Text(
                    fileName,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        extension.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: _getArchiveColor(extension),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.info, size: 18),
                            SizedBox(width: 8),
                            Text('Info'),
                          ],
                        ),
                        onTap: () {
                          // Show file info
                        },
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.folder_open, size: 18),
                            SizedBox(width: 8),
                            Text('Extract'),
                          ],
                        ),
                        onTap: () {
                          // Handle extraction
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

### 8. 🔍 Custom File Format Management

```dart
class CustomFormatManager extends StatefulWidget {
  @override
  _CustomFormatManagerState createState() => _CustomFormatManagerState();
}

class _CustomFormatManagerState extends State<CustomFormatManager> {
  final mediaManager = MediaManager();
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
      print('Loading $_selectedCategory files with formats: ${formats.join(", ")}');
      
      final filePaths = await mediaManager.getAllFilesByFormat(formats);
      print('Found ${filePaths.length} $_selectedCategory files');
      
      setState(() {
        _filePaths = filePaths;
      });
      
      if (filePaths.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${filePaths.length} $_selectedCategory files'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error loading $_selectedCategory files: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading files: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _loadFiles,
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Color _getColorForExtension(String extension) {
    switch (extension.toLowerCase()) {
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
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category selector
        Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select File Category:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
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
              SizedBox(height: 8),
              Text(
                'Formats: ${_formatCategories[_selectedCategory]?.join(", ") ?? ""}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        // Refresh button
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadFiles,
              icon: _isLoading 
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.refresh),
              label: Text(_isLoading ? 'Loading...' : 'Refresh $_selectedCategory'),
            ),
          ),
        ),
        
        SizedBox(height: 16),
        
        // File list
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _filePaths.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No $_selectedCategory files found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Supported formats: ${_formatCategories[_selectedCategory]?.join(", ") ?? ""}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _filePaths.length,
                  itemBuilder: (context, index) {
                    final filePath = _filePaths[index];
                    final fileName = filePath.split('/').last;
                    final fileExtension = fileName.split('.').last.toLowerCase();
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getColorForExtension(fileExtension),
                          child: Text(
                            fileExtension.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          fileName,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          filePath,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          _getIconForCategory(_selectedCategory),
                          color: Theme.of(context).primaryColor,
                        ),
                        onTap: () {
                          // Handle file tap
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('File Information'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Name: $fileName'),
                                  SizedBox(height: 8),
                                  Text('Type: $fileExtension'),
                                  SizedBox(height: 8),
                                  Text('Path: $filePath'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Example usage of multiple format searches:
class MultiFormatSearch extends StatefulWidget {
  @override
  _MultiFormatSearchState createState() => _MultiFormatSearchState();
}

class _MultiFormatSearchState extends State<MultiFormatSearch> {
  final mediaManager = MediaManager();
  Map<String, List<String>> _results = {};
  bool _isLoading = false;
  
  Future<void> _searchAllFormats() async {
    setState(() {
      _isLoading = true;
      _results.clear();
    });
    
    try {
      // Search for different file types
      final futures = <String, Future<List<String>>>{
        'Applications': mediaManager.getAllFilesByFormat(['apk', 'exe', 'msi']),
        'Source Code': mediaManager.getAllFilesByFormat(['dart', 'java', 'kt', 'swift', 'py']),
        'Archives': mediaManager.getAllFilesByFormat(['zip', 'rar', '7z', 'tar']),
        'Configuration': mediaManager.getAllFilesByFormat(['json', 'xml', 'yaml', 'ini']),
        'Database': mediaManager.getAllFilesByFormat(['db', 'sqlite', 'sql']),
      };
      
      // Wait for all searches to complete
      final results = await Future.wait(futures.values);
      final keys = futures.keys.toList();
      
      for (int i = 0; i < keys.length; i++) {
        _results[keys[i]] = results[i];
      }
      
      setState(() {
        _isLoading = false;
      });
      
      // Show summary
      int totalFiles = _results.values.map((list) => list.length).reduce((a, b) => a + b);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found $totalFiles files across all categories'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _searchAllFormats,
            icon: _isLoading ? CircularProgressIndicator() : Icon(Icons.search),
            label: Text(_isLoading ? 'Searching...' : 'Search All Formats'),
          ),
        ),
        Expanded(
          child: _results.isEmpty
              ? Center(child: Text('No results yet'))
              : ListView.builder(
                  itemCount: _results.keys.length,
                  itemBuilder: (context, index) {
                    String category = _results.keys.elementAt(index);
                    List<String> files = _results[category]!;
                    
                    return ExpansionTile(
                      title: Text('$category (${files.length} files)'),
                      children: files.take(5).map((path) {
                        return ListTile(
                          title: Text(path.split('/').last),
                          subtitle: Text(path),
                        );
                      }).toList(),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
```

### 9. 🎥 Video & Audio Thumbnails

#### Video Thumbnail Generation

```dart
class VideoThumbnailViewer extends StatefulWidget {
  final String videoPath;
  
  const VideoThumbnailViewer({Key? key, required this.videoPath}) : super(key: key);
  
  @override
  _VideoThumbnailViewerState createState() => _VideoThumbnailViewerState();
}

class _VideoThumbnailViewerState extends State<VideoThumbnailViewer> {
  final mediaManager = MediaManager();
  
  void _showFullScreenPreview(Uint8List thumbnailData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Video Preview'),
            backgroundColor: Colors.black,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(
                thumbnailData,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final fileName = widget.videoPath.split('/').last;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: FutureBuilder<Uint8List?>(
              future: mediaManager.getVideoThumbnail(widget.videoPath),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text(
                            'Generating thumbnail...',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                if (snapshot.hasError) {
                  return Container(
                    color: Colors.red[50],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Failed to generate thumbnail',
                            style: TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() {}),
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                if (snapshot.hasData && snapshot.data != null) {
                  return GestureDetector(
                    onTap: () => _showFullScreenPreview(snapshot.data!),
                    child: Stack(
                      children: [
                        Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        // Play overlay
                        Container(
                          color: Colors.black26,
                          child: Center(
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                        // Duration overlay (optional)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'VIDEO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_file, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'No thumbnail available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  widget.videoPath,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### Audio Album Art Extraction

```dart
class AudioAlbumArtViewer extends StatefulWidget {
  final String audioPath;
  
  const AudioAlbumArtViewer({Key? key, required this.audioPath}) : super(key: key);
  
  @override
  _AudioAlbumArtViewerState createState() => _AudioAlbumArtViewerState();
}

class _AudioAlbumArtViewerState extends State<AudioAlbumArtViewer> {
  final mediaManager = MediaManager();
  
  void _showFullScreenAlbumArt(Uint8List albumArt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Album Art'),
            backgroundColor: Colors.black,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(
                albumArt,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final fileName = widget.audioPath.split('/').last;
    final fileNameWithoutExt = fileName.split('.').first;
    
    return Card(
      child: ListTile(
        leading: Container(
          width: 56,
          height: 56,
          child: FutureBuilder<Uint8List?>(
            future: mediaManager.getAudioThumbnail(widget.audioPath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              
              if (snapshot.hasData && snapshot.data != null) {
                return GestureDetector(
                  onTap: () => _showFullScreenAlbumArt(snapshot.data!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Icon(
                              Icons.music_note,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Default music icon
              return Container(
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Icon(
                  Icons.music_note,
                  color: Colors.blue[600],
                  size: 28,
                ),
              );
            },
          ),
        ),
        title: Text(
          fileNameWithoutExt,
          style: TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.audioPath.split('/').last.split('.').last.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.audioPath,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(Icons.play_arrow, size: 18),
                  SizedBox(width: 8),
                  Text('Play'),
                ],
              ),
              onTap: () {
                // Handle audio playback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playing: $fileName'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(Icons.info, size: 18),
                  SizedBox(width: 8),
                  Text('Info'),
                ],
              ),
              onTap: () {
                // Show file info
                Future.delayed(Duration.zero, () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Audio File Info'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Name: $fileName'),
                          SizedBox(height: 8),
                          Text('Path: ${widget.audioPath}'),
                          SizedBox(height: 8),
                          Text('Format: ${fileName.split('.').last.toUpperCase()}'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Close'),
                        ),
                      ],
                    ),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
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

### Custom File Formats (via getAllFilesByFormat)
- **Applications**: apk, ipa, exe, msi, deb, rpm
- **Source Code**: dart, java, kt, swift, py, js, ts, cpp, c, h
- **Configuration**: json, xml, yaml, yml, ini, cfg, conf
- **Database**: db, sqlite, sql, mdb
- **Additional Archives**: rar, 7z, tar, gz, bz2, xz
- **And any other file extension you specify**

## 📱 Platform Specific Notes

### 🤖 Android
- **Android 5.0-9.0**: Requires `READ_EXTERNAL_STORAGE` permission
- **Android 10**: Scoped storage with legacy compatibility mode
- **Android 11+**: Enhanced with `MANAGE_EXTERNAL_STORAGE` for full access
- **Android 13+**: Granular media permissions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`)
- **Android 14+**: Partial media access with `READ_MEDIA_VISUAL_USER_SELECTED`
- **Android 15+**: Optimized performance and battery usage
- **Android 16**: Future-ready with latest security enhancements
- Supports all file types and operations across all versions
- Full access to external storage (with proper permissions)
- Advanced file scanning with MediaStore API integration

### 🍏 iOS
- **iOS 12.0+**: Uses Photos framework for media access
- **iOS 14.0+**: Enhanced privacy with limited photo library access
- **iOS 15.0+**: Improved performance for large media libraries
- **iOS 16.0+**: Advanced thumbnail generation and caching
- **iOS 17.0+**: Enhanced security and privacy controls
- **iOS 18.0**: Latest features and optimizations
- Limited to user's media library (Photos app content)
- Some file operations may be restricted due to iOS sandboxing
- Requires photo library access permission
- Excellent performance with built-in caching

### 💻 macOS
- **macOS 11.0+**: Uses AppKit/NSImage for image processing
- **macOS 12.0+**: Enhanced file system security
- **macOS 13.0+**: Improved performance for large directories
- **macOS 14.0+**: Advanced file management capabilities
- **macOS 15.0**: Latest features and security enhancements
- Uses FileManager for comprehensive file operations
- Full access to file system (with user permission)
- Supports all file types and operations
- Handles macOS-specific file attributes and metadata
- Compatible with both sandboxed and non-sandboxed environments
- Excellent integration with Finder and system file dialogs

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
