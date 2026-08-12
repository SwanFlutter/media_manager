import 'package:flutter_test/flutter_test.dart';
import 'package:media_manager/media_manager.dart';
import 'package:media_manager/media_manager_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMediaManagerPlatform
    with MockPlatformInterfaceMixin
    implements MediaManagerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> clearThumbnailCache() {
    throw UnimplementedError();
  }

  @override
  Future<int> getMediaCount({
    MediaType type = MediaType.any,
    List<String> extensions = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<MediaItem>> getMediaPage({
    MediaType type = MediaType.any,
    List<String> extensions = const [],
    int page = 0,
    int pageSize = 100,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String?> getThumbnail({
    required String uriOrPath,
    int width = 256,
    int? height,
    int dateModified = 0,
    String kind = 'image',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasStoragePermission() {
    throw UnimplementedError();
  }

  @override
  Future<void> openAllFilesAccessSettings() {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, String>>> getDirectories() {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> getDirectoryContents({
    required String path,
    int page = 0,
    int pageSize = 200,
  }) {
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
