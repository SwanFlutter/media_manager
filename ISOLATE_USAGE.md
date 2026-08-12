# Isolate Support in MediaManager Plugin

## Overview

The MediaManager plugin now includes isolate support to prevent UI freezing when performing heavy file operations. This is especially important when scanning large numbers of media files or processing directories with thousands of files.

## Features Added

### 1. Isolate Worker System
- **File Scanning Isolate**: Handles `getAllImages()`, `getAllVideos()`, `getAllAudio()`, `getAllDocuments()`, `getAllZipFiles()`
- **Directory Scanning Isolate**: Handles `getDirectories()`, `getDirectoryContents()`
- **Image Processing Isolate**: Handles `getImagePreview()`, `clearImageCache()`

### 2. Automatic Isolate Management
- Isolates are created on-demand when first needed
- Proper cleanup when the app is disposed
- Configurable enable/disable functionality

## Usage

### Basic Usage (Isolates Enabled by Default)

```dart
import 'package:media_manager/media_manager.dart';

final mediaManager = MediaManager();

// These operations now run in isolates automatically
List<String> images = await mediaManager.getAllImages();
List<String> videos = await mediaManager.getAllVideos();
List<Map<String, dynamic>> directories = await mediaManager.getDirectories();
```

### Controlling Isolate Usage

```dart
// Disable isolates (operations run on main thread)
MediaManager.setIsolateUsage(false);

// Enable isolates (default behavior)
MediaManager.setIsolateUsage(true);

// Check current status
// Note: You can track this in your app state
```

### Proper Cleanup

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    // Important: Dispose isolates when app is closing
    MediaManager.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Your app UI
  }
}
```

## Performance Benefits

### Without Isolates
- Heavy file operations block the UI thread
- App becomes unresponsive during large scans
- Poor user experience with frozen interface

### With Isolates
- File operations run in background threads
- UI remains responsive during heavy operations
- Better user experience with smooth animations
- Prevents ANR (Application Not Responding) errors

## Example Implementation

The example app demonstrates isolate usage with a toggle button:

```dart
class _MediaManagerScreenState extends State<MediaManagerScreen> {
  bool _isolatesEnabled = true;
  
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
      ),
    );
  }
  
  @override
  void dispose() {
    MediaManager.dispose(); // Clean up isolates
    super.dispose();
  }
}
```

## Technical Details

### Isolate Architecture

1. **IsolateWorker**: Contains static methods that run in isolates
2. **IsolateManager**: Manages isolate lifecycle and communication
3. **MediaManager**: Updated to use isolates when enabled

### Communication Flow

```
Main Thread → IsolateManager → Isolate Worker → Platform Implementation
     ↑                                                        ↓
Result ← SendPort/ReceivePort Communication ← Platform Result
```

### Error Handling

- Isolate errors are properly caught and returned to main thread
- Fallback to main thread execution if isolate fails
- Comprehensive error messages for debugging

## Best Practices

1. **Always call `MediaManager.dispose()`** in your app's dispose method
2. **Use isolates for heavy operations** like scanning thousands of files
3. **Consider disabling isolates** for small, quick operations if needed
4. **Monitor memory usage** when processing very large file sets

## Troubleshooting

### Common Issues

1. **Memory Issues**: If processing extremely large file sets, consider batch processing
2. **Isolate Startup Overhead**: First isolate operation may be slightly slower
3. **Platform Limitations**: Some platforms may have isolate restrictions

### Debug Mode

You can disable isolates for debugging:

```dart
// In debug mode, you might want to disable isolates for easier debugging
if (kDebugMode) {
  MediaManager.setIsolateUsage(false);
}
```

## Compatibility

- ✅ Android: Full support
- ✅ iOS: Full support  
- ✅ macOS: Full support
- ✅ Flutter 3.3.0+
- ✅ Dart 3.7.2+

## Migration Guide

### From Previous Version

No breaking changes! Isolates are enabled by default, but you can disable them:

```dart
// If you want the old behavior (main thread execution)
MediaManager.setIsolateUsage(false);
```

### Adding to Existing Apps

1. Update to the new version
2. Add `MediaManager.dispose()` to your app's dispose method
3. Optionally add isolate toggle functionality for users
