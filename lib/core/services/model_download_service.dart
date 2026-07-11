import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_config.dart';

enum DownloadState {
  notStarted,
  downloading,
  paused,
  completed,
  failed,
}

@pragma('vm:entry-point')
class ModelDownloadService {
  static const String _portName = 'model_downloader_send_port';
  final ReceivePort _port = ReceivePort();
  
  // Observers can listen to this ValueNotifier for status updates
  final ValueNotifier<DownloadState> stateNotifier = ValueNotifier(DownloadState.notStarted);
  final ValueNotifier<int> progressNotifier = ValueNotifier(0);
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);

  String? _taskId;
  
  // Callback registered as a top-level/static function to be run in the background isolate
  @pragma('vm:entry-point')
  static void downloadCallback(String id, int statusValue, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(_portName);
    send?.send([id, statusValue, progress]);
  }

  Future<void> init() async {
    // 1. Initialize FlutterDownloader
    await FlutterDownloader.initialize(debug: true, ignoreSsl: true);

    // 2. Set up IsolateNameServer communication port
    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(_port.sendPort, _portName);

    // 3. Listen to download updates from background isolate
    _port.listen((dynamic data) {
      final String id = data[0] as String;
      final int statusValue = data[1] as int;
      final int progress = data[2] as int;
      final status = DownloadTaskStatus.values[statusValue];

      debugPrint("[ModelDownloadService] Port update - ID: $id, Progress: $progress%, Status: ${status.name}");

      if (_taskId == id) {
        progressNotifier.value = progress;
        _updateStateFromStatus(status);
      }
    });

    // 4. Register the background callback
    await FlutterDownloader.registerCallback(downloadCallback);

    // 5. Restore active download task if one exists
    await _restoreActiveTask();
  }

  void dispose() {
    IsolateNameServer.removePortNameMapping(_portName);
    _port.close();
  }

  static const MethodChannel _diskChannel = MethodChannel('com.lxmwaniky.inkq/disk_space');

  Future<int> getFreeDiskSpace() async {
    try {
      final int freeSpace = await _diskChannel.invokeMethod('getFreeDiskSpace');
      return freeSpace;
    } catch (e) {
      debugPrint("Failed to get free disk space: $e");
      return -1; // Unknown / error
    }
  }

  Future<bool> isModelDownloaded() async {
    final file = File(await getModelPath());

    if (await file.exists()) {
      try {
        final size = await file.length();
        // Check if file is at least 2.5 GB (2,500,000,000 bytes)
        if (size >= 2500000000) {
          return true;
        } else {
          debugPrint("Incomplete model file detected ($size bytes). Deleting...");
          await file.delete();
        }
      } catch (e) {
        debugPrint("Error reading/deleting model file: $e");
      }
    }
    return false;
  }

  Future<String> getModelPath() async {
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}/${AppConfig.modelFilename}';
  }

  Future<void> startDownload() async {
    // Check/request Notification permissions on Android 13+ / iOS
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }

    final hasFile = await isModelDownloaded();
    if (hasFile) {
      debugPrint("[ModelDownloadService] Model file is already downloaded.");
      stateNotifier.value = DownloadState.completed;
      progressNotifier.value = 100;
      return;
    }

    // HuggingFace direct download link
    const downloadUrl = 'https://huggingface.co/${AppConfig.hfModelRepo}/resolve/main/${AppConfig.modelFilename}';

    stateNotifier.value = DownloadState.downloading;
    progressNotifier.value = 0;
    errorNotifier.value = null;

    try {
      debugPrint("[ModelDownloadService] Pre-flight check on: $downloadUrl");
      final response = await http.head(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 10));
      debugPrint("[ModelDownloadService] Pre-flight response code: ${response.statusCode}");
      if (response.statusCode >= 400) {
        stateNotifier.value = DownloadState.failed;
        errorNotifier.value = "Server access denied (HTTP ${response.statusCode}). Please verify connection.";
        return;
      }
    } catch (e) {
      debugPrint("[ModelDownloadService] Pre-flight failed: $e");
      stateNotifier.value = DownloadState.failed;
      errorNotifier.value = "Failed to connect to HuggingFace. Please verify network access.";
      return;
    }

    final directory = await getApplicationSupportDirectory();
    final savePath = directory.path;

    debugPrint("[ModelDownloadService] Initiating download. URL: $downloadUrl, SavePath: $savePath");

    // Start background download directly with the final model file name and User-Agent headers
    _taskId = await FlutterDownloader.enqueue(
      url: downloadUrl,
      savedDir: savePath,
      fileName: AppConfig.modelFilename,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Mobile Safari/537.36',
      },
      showNotification: true, // Show progress in Notification Bar
      openFileFromNotification: false,
      saveInPublicStorage: false, // Store in private ApplicationSupport sandbox
      allowCellular: true, // Let download continue over cellular if configured
    );

    if (_taskId != null) {
      debugPrint("[ModelDownloadService] Download task enqueued. TaskID: $_taskId");
      stateNotifier.value = DownloadState.downloading;
      errorNotifier.value = null;
    } else {
      debugPrint("[ModelDownloadService] Failed to enqueue download task.");
      stateNotifier.value = DownloadState.failed;
      errorNotifier.value = "Failed to queue download task.";
    }
  }

  Future<void> cancelDownload() async {
    if (_taskId != null) {
      try {
        await FlutterDownloader.remove(taskId: _taskId!, shouldDeleteContent: true);
      } catch (e) {
        debugPrint("Error removing task via FlutterDownloader: $e");
      }
      _taskId = null;
    }
    
    await _cleanupModelFiles();

    stateNotifier.value = DownloadState.notStarted;
    progressNotifier.value = 0;
  }

  /// Sweeps the app directory and purges any corrupt model file or partial download artifacts
  Future<void> _cleanupModelFiles() async {
    try {
      final file = File(await getModelPath());
      if (await file.exists()) {
        await file.delete();
        debugPrint("Deleted main model file.");
      }

      // Sweep the directory for any partial download parts left behind
      final directory = await getApplicationSupportDirectory();
      if (await directory.exists()) {
        final List<FileSystemEntity> files = directory.listSync();
        final partialExtensions = ['.part', '.tmp', '.download', '.crdownload'];
        
        for (final f in files) {
          if (f is File) {
            final pathLower = f.path.toLowerCase();
            final isPartial = partialExtensions.any((ext) => pathLower.endsWith(ext));
            final isStrayModel = pathLower.contains('gemma') || pathLower.contains('litertlm');

            if (isPartial || isStrayModel) {
              await f.delete();
              debugPrint("Cleaned up orphaned/partial file: ${f.path}");
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error during directory cleanup: $e");
    }
  }

  /// Nuclear reset option for user Settings
  Future<void> purgeAllModelFiles() async {
    await cancelDownload();
    stateNotifier.value = DownloadState.notStarted;
    progressNotifier.value = 0;
    errorNotifier.value = null;
  }

  Future<void> _restoreActiveTask() async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks != null && tasks.isNotEmpty) {
      // Find the task matching AppConfig.modelFilename
      final modelTask = tasks.firstWhere(
        (task) => task.filename == AppConfig.modelFilename,
        orElse: () => tasks.first,
      );

      if (modelTask.filename == AppConfig.modelFilename) {
        _taskId = modelTask.taskId;
        progressNotifier.value = modelTask.progress;
        
        if (modelTask.status == DownloadTaskStatus.complete) {
          _handleDownloadCompletion();
        } else {
          _updateStateFromStatus(modelTask.status);
        }
      }
    }

    // Double check file existence if status is completed
    if (await isModelDownloaded()) {
      stateNotifier.value = DownloadState.completed;
      progressNotifier.value = 100;
    }
  }

  void _handleDownloadCompletion() {
    stateNotifier.value = DownloadState.completed;
    progressNotifier.value = 100;
  }

  void _updateStateFromStatus(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.enqueued:
      case DownloadTaskStatus.running:
        stateNotifier.value = DownloadState.downloading;
        break;
      case DownloadTaskStatus.complete:
        _handleDownloadCompletion();
        break;
      case DownloadTaskStatus.failed:
        stateNotifier.value = DownloadState.failed;
        errorNotifier.value = "Download failed. Please check network.";
        break;
      case DownloadTaskStatus.canceled:
        stateNotifier.value = DownloadState.notStarted;
        progressNotifier.value = 0;
        break;
      case DownloadTaskStatus.paused:
        stateNotifier.value = DownloadState.paused;
        break;
      default:
        break;
    }
  }
}
