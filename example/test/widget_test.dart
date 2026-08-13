import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_manager/media_manager.dart';
import 'package:media_manager_example/main.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeMediaManagerPlatform
    with MockPlatformInterfaceMixin
    implements MediaManagerPlatform {
  @override
  Future<String?> getPlatformVersion() async => 'Test OS 1.0';

  @override
  Future<void> clearThumbnailCache() async {}

  @override
  Future<int> getMediaCount({
    MediaType type = MediaType.any,
    List<String> extensions = const [],
  }) async => 0;

  @override
  Future<List<MediaItem>> getMediaPage({
    MediaType type = MediaType.any,
    List<String> extensions = const [],
    int page = 0,
    int pageSize = 100,
  }) async => const [];

  @override
  Future<String?> getThumbnail({
    required String uriOrPath,
    int width = 256,
    int? height,
    int dateModified = 0,
    String kind = 'image',
  }) async => null;

  @override
  Future<bool> hasStoragePermission() async => true;

  @override
  Future<void> openAllFilesAccessSettings() async {}

  @override
  Future<List<Map<String, String>>> getDirectories() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getDirectoryContents({
    required String path,
    int page = 0,
    int pageSize = 200,
  }) async => const [];

  @override
  Future<bool> requestStoragePermission() async => true;
}

void main() {
  testWidgets('Home screen renders title and all tabs', (
    WidgetTester tester,
  ) async {
    MediaManagerPlatform.instance = _FakeMediaManagerPlatform();

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Media Manager Demo'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(6));
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('No directories found. Tap Refresh.'), findsOneWidget);
  });
}
