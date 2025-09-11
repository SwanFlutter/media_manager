import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_manager_platform_interface.dart';

/// The platform-specific implementation of MediaManager using method channels.
/// This class handles all communication between Dart and native platforms (Android/iOS).
class MethodChannelMediaManager extends MediaManagerPlatform {
  /// The method channel used to interact with the native platform.
  /// Marked as @visibleForTesting to allow test code to mock the channel.
  @visibleForTesting
  final methodChannel = const MethodChannel('media_manager');

  /// Gets the platform version using the method channel.
  /// Returns a String containing the platform version information.
  /// Example:
  /// ```dart
  /// String? version = await MethodChannelMediaManager().getPlatformVersion();
  /// print('Running on: $version');
  /// ```
  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  /// Retrieves device directories through the platform channel.
  /// Returns a List of Maps with directory information (name, path, etc.).
  /// Example:
  /// ```dart
  /// var directories = await MethodChannelMediaManager().getDirectories();
  /// ```
  @override
  Future<List<Map<String, dynamic>>> getDirectories() async {
    final List<dynamic> rawDirectories = await methodChannel.invokeMethod(
      'getDirectories',
    );
    final List<Map<String, dynamic>> directories =
        rawDirectories
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    return directories;
  }

  /// Gets contents of a specific directory by its path.
  /// [path] - The absolute path of the directory to scan.
  /// Returns a List of Maps with file/folder details.
  /// Example:
  /// ```dart
  /// var contents = await MethodChannelMediaManager().getDirectoryContents('/storage/DCIM');
  /// ```
  @override
  Future<List<Map<String, dynamic>>> getDirectoryContents(String path) async {
    final List<dynamic> rawContents = await methodChannel.invokeMethod(
      'getDirectoryContents',
      {'path': path},
    );
    final List<Map<String, dynamic>> contents =
        rawContents
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    return contents;
  }

  /// Retrieves an image thumbnail/preview as a byte array.
  /// [path] - The path of the image file.
  /// Returns Uint8List containing image data or null if unavailable.
  /// Example:
  /// ```dart
  /// Uint8List? preview = await MethodChannelMediaManager().getImagePreview('/path/to/image.jpg');
  /// ```
  @override
  Future<Uint8List?> getImagePreview(String path) async {
    final Uint8List? data = await methodChannel.invokeMethod(
      'getImagePreview',
      {'path': path},
    );
    return data;
  }

  /// Clears cached image thumbnails.
  /// Returns true if the operation succeeded.
  /// Example:
  /// ```dart
  /// bool success = await MethodChannelMediaManager().clearImageCache();
  /// ```
  @override
  Future<bool> clearImageCache() async {
    final bool result = await methodChannel.invokeMethod('clearImageCache');
    return result;
  }

  /// Requests storage permission from the user.
  /// Returns true if permission was granted.
  /// Example:
  /// ```dart
  /// bool granted = await MethodChannelMediaManager().requestStoragePermission();
  /// ```
  @override
  Future<bool> requestStoragePermission() async {
    final bool result = await methodChannel.invokeMethod(
      'requestStoragePermission',
    );
    return result;
  }

  /// Retrieves paths of all image files on device.
  /// Returns List< String> of absolute file paths.
  /// Example:
  /// ```dart
  /// List<String> images = await MethodChannelMediaManager().getAllImages();
  /// ```
  @override
  Future<List<String>> getAllImages() async {
    final List<dynamic> result = await methodChannel.invokeMethod(
      'getAllImages',
    );
    return result.cast<String>();
  }

  /// Retrieves paths of all video files on device.
  /// Returns List< String> of absolute file paths.
  /// Example:
  /// ```dart
  /// List<String> videos = await MethodChannelMediaManager().getAllVideos();
  /// ```
  @override
  Future<List<String>> getAllVideos() async {
    final List<dynamic> result = await methodChannel.invokeMethod(
      'getAllVideos',
    );
    return result.cast<String>();
  }

  /// Retrieves paths of all audio files on device.
  /// Returns List< String> of absolute file paths.
  /// Example:
  /// ```dart
  /// List<String> audioFiles = await MethodChannelMediaManager().getAllAudio();
  /// ```
  @override
  Future<List<String>> getAllAudio() async {
    final List<dynamic> result = await methodChannel.invokeMethod(
      'getAllAudio',
    );
    return result.cast<String>();
  }

  /// Retrieves paths of all document files on device.
  /// Returns List< String> of absolute file paths.
  /// Example:
  /// ```dart
  /// List<String> docs = await MethodChannelMediaManager().getAllDocuments();
  /// ```
  @override
  Future<List<String>> getAllDocuments() async {
    final List<dynamic> result = await methodChannel.invokeMethod(
      'getAllDocuments',
    );
    return result.cast<String>();
  }

  /// Retrieves paths of all zip files on device.
  /// Returns List< String> of absolute file paths.
  /// Example:
  /// ```dart
  /// List<String> zips = await MethodChannelMediaManager().getAllZipFiles();
  /// ```
  @override
  Future<List<String>> getAllZipFiles() async {
    final List<dynamic> result = await methodChannel.invokeMethod(
      'getAllZipFiles',
    );
    return result.cast<String>();
  }

  /// Generates a thumbnail for a video file.
  /// [videoPath] - The path of the video file.
  /// Returns Uint8List containing thumbnail data or null if generation fails.
  /// Example:
  /// ```dart
  /// Uint8List? thumbnail = await MethodChannelMediaManager().getVideoThumbnail('/path/to/video.mp4');
  /// ```
  @override
  Future<Uint8List?> getVideoThumbnail(String videoPath) async {
    final Uint8List? data = await methodChannel.invokeMethod(
      'getVideoThumbnail',
      {'path': videoPath},
    );
    return data;
  }

  /// Extracts album art from an audio file.
  /// [audioPath] - The path of the audio file.
  /// Returns Uint8List containing album art data or null if not available.
  /// Example:
  /// ```dart
  /// Uint8List? albumArt = await MethodChannelMediaManager().getAudioThumbnail('/path/to/audio.mp3');
  /// ```
  @override
  Future<Uint8List?> getAudioThumbnail(String audioPath) async {
    final result = await methodChannel.invokeMethod<Uint8List>(
      'getAudioThumbnail',
      {'path': audioPath},
    );
    return result;
  }

  @override
  Future<List<String>> getAllFilesByFormat(List<String> formats) async {
    try {
      final result = await methodChannel.invokeMethod<List<dynamic>>(
        'getAllFilesByFormat',
        {'formats': formats},
      );
      if (result != null) {
        return result.cast<String>();
      }
      return [];
    } catch (e) {
      // Log error and return empty list
      debugPrint('Error in getAllFilesByFormat: $e');
      return [];
    }
  }
}
