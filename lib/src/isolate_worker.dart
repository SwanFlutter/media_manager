import 'dart:isolate';

import '../media_manager_platform_interface.dart';

/// Isolate worker functions for heavy media operations
class IsolateWorker {
  /// Entry point for file scanning isolate
  static void scanFilesIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is Map<String, dynamic>) {
        final String operation = message['operation'];
        final SendPort replyPort = message['replyPort'];

        try {
          List<String> result;
          switch (operation) {
            case 'getAllImages':
              result = await MediaManagerPlatform.instance.getAllImages();
              break;
            case 'getAllVideos':
              result = await MediaManagerPlatform.instance.getAllVideos();
              break;
            case 'getAllAudio':
              result = await MediaManagerPlatform.instance.getAllAudio();
              break;
            case 'getAllDocuments':
              result = await MediaManagerPlatform.instance.getAllDocuments();
              break;
            case 'getAllZipFiles':
              result = await MediaManagerPlatform.instance.getAllZipFiles();
              break;
            case 'getAllFilesByFormat':
              final args = message['args'];
              if (args is List<String>) {
                result = await MediaManagerPlatform.instance
                    .getAllFilesByFormat(args);
              } else {
                result = <String>[];
              }
              break;
            default:
              result = [];
          }
          replyPort.send({'success': true, 'data': result});
        } catch (e) {
          replyPort.send({'success': false, 'error': e.toString()});
        }
      }
    });
  }

  /// Entry point for directory scanning isolate
  static void scanDirectoryIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is Map<String, dynamic>) {
        final String operation = message['operation'];
        final SendPort replyPort = message['replyPort'];

        try {
          dynamic result;
          switch (operation) {
            case 'getDirectories':
              result = await MediaManagerPlatform.instance.getDirectories();
              break;
            case 'getDirectoryContents':
              final String path = message['path'];
              result = await MediaManagerPlatform.instance.getDirectoryContents(
                path,
              );
              break;
            default:
              result = [];
          }
          replyPort.send({'success': true, 'data': result});
        } catch (e) {
          replyPort.send({'success': false, 'error': e.toString()});
        }
      }
    });
  }

  /// Entry point for image processing isolate
  static void imageProcessingIsolate(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is Map<String, dynamic>) {
        final String operation = message['operation'];
        final SendPort replyPort = message['replyPort'];

        try {
          dynamic result;
          switch (operation) {
            case 'getImagePreview':
              final String path = message['path'];
              result = await MediaManagerPlatform.instance.getImagePreview(
                path,
              );
              break;
            case 'clearImageCache':
              result = await MediaManagerPlatform.instance.clearImageCache();
              break;
            default:
              result = null;
          }
          replyPort.send({'success': true, 'data': result});
        } catch (e) {
          replyPort.send({'success': false, 'error': e.toString()});
        }
      }
    });
  }
}

/// Helper class to manage isolate operations
class IsolateManager {
  static Isolate? _filesScanIsolate;
  static Isolate? _directoryScanIsolate;
  static Isolate? _imageProcessingIsolate;

  static SendPort? _filesScanSendPort;
  static SendPort? _directoryScanSendPort;
  static SendPort? _imageProcessingSendPort;

  /// Initialize file scanning isolate
  static Future<void> initFilesScanIsolate() async {
    if (_filesScanIsolate != null) return;

    final receivePort = ReceivePort();
    _filesScanIsolate = await Isolate.spawn(
      IsolateWorker.scanFilesIsolate,
      receivePort.sendPort,
    );

    _filesScanSendPort = await receivePort.first as SendPort;
  }

  /// Initialize directory scanning isolate
  static Future<void> initDirectoryScanIsolate() async {
    if (_directoryScanIsolate != null) return;

    final receivePort = ReceivePort();
    _directoryScanIsolate = await Isolate.spawn(
      IsolateWorker.scanDirectoryIsolate,
      receivePort.sendPort,
    );

    _directoryScanSendPort = await receivePort.first as SendPort;
  }

  /// Initialize image processing isolate
  static Future<void> initImageProcessingIsolate() async {
    if (_imageProcessingIsolate != null) return;

    final receivePort = ReceivePort();
    _imageProcessingIsolate = await Isolate.spawn(
      IsolateWorker.imageProcessingIsolate,
      receivePort.sendPort,
    );

    _imageProcessingSendPort = await receivePort.first as SendPort;
  }

  /// Execute operation in files scan isolate
  static Future<List<String>> executeFilesScanOperation(
    String operation,
    List<String> formats,
  ) async {
    await initFilesScanIsolate();

    final receivePort = ReceivePort();
    _filesScanSendPort!.send({
      'operation': operation,
      'args': formats,
      'replyPort': receivePort.sendPort,
    });

    final response = await receivePort.first as Map<String, dynamic>;
    if (response['success']) {
      final data = response['data'];
      if (data is List) {
        return data.cast<String>();
      }
      return [];
    } else {
      throw Exception(response['error']);
    }
  }

  /// Execute operation in directory scan isolate
  static Future<T> executeDirectoryScanOperation<T>(
    String operation, {
    String? path,
  }) async {
    await initDirectoryScanIsolate();

    final receivePort = ReceivePort();
    final message = {'operation': operation, 'replyPort': receivePort.sendPort};

    if (path != null) {
      message['path'] = path;
    }

    _directoryScanSendPort!.send(message);

    final response = await receivePort.first as Map<String, dynamic>;
    if (response['success']) {
      return response['data'] as T;
    } else {
      throw Exception(response['error']);
    }
  }

  /// Execute operation in image processing isolate
  static Future<T> executeImageProcessingOperation<T>(
    String operation, {
    String? path,
  }) async {
    await initImageProcessingIsolate();

    final receivePort = ReceivePort();
    final message = {'operation': operation, 'replyPort': receivePort.sendPort};

    if (path != null) {
      message['path'] = path;
    }

    _imageProcessingSendPort!.send(message);

    final response = await receivePort.first as Map<String, dynamic>;
    if (response['success']) {
      return response['data'] as T;
    } else {
      throw Exception(response['error']);
    }
  }

  /// Dispose all isolates
  static void dispose() {
    _filesScanIsolate?.kill();
    _directoryScanIsolate?.kill();
    _imageProcessingIsolate?.kill();

    _filesScanIsolate = null;
    _directoryScanIsolate = null;
    _imageProcessingIsolate = null;

    _filesScanSendPort = null;
    _directoryScanSendPort = null;
    _imageProcessingSendPort = null;
  }
}
