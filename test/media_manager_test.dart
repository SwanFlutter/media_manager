import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_manager/media_manager.dart';
import 'package:media_manager/media_manager_method_channel.dart';
import 'package:media_manager/media_manager_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMediaManagerPlatform
    with MockPlatformInterfaceMixin
    implements MediaManagerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> clearAllCaches() {
    throw UnimplementedError();
  }

  @override
  Future<bool> clearImageCache() {
    // TODO: implement clearImageCache
    throw UnimplementedError();
  }

  @override
  Future<bool> clearVideoThumbnailCache() {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllAudio() {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getAllDocuments() {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getAllImages() {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getAllVideos() {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getAllZipFiles() {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> getDirectories() {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> getDirectoryContents(String path) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List?> getImagePreview(String path) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List?> getVideoThumbnail(String path) {
    throw UnimplementedError();
  }

  @override
  Future<bool> requestMacStoragePermission() {
    throw UnimplementedError();
  }

  @override
  Future<bool> requestStoragePermission() {
    throw UnimplementedError();
  }
}

void main() {
  final MediaManagerPlatform initialPlatform = MediaManagerPlatform.instance;

  test('$MethodChannelMediaManager is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMediaManager>());
  });

  test('getPlatformVersion', () async {
    MediaManager mediaManagerPlugin = MediaManager();
    MockMediaManagerPlatform fakePlatform = MockMediaManagerPlatform();
    MediaManagerPlatform.instance = fakePlatform;

    expect(await mediaManagerPlugin.getPlatformVersion(), '42');
  });
}
