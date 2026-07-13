import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'core/theme/app_colors.dart';
import 'core/services/model_download_service.dart';
import 'features/chat/data/repositories/chat_repository_impl.dart';
import 'features/chat/domain/repositories/chat_repository.dart';
import 'features/chat/presentation/screens/hub_screen.dart';
import 'features/chat/presentation/screens/model_download_screen.dart';
import 'features/chat/presentation/state/chat_notifier.dart';

void main() async {
  // Required by flutter_downloader and path_provider before running App
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_gemma with LiteRtLmEngine
  await FlutterGemma.initialize(
    inferenceEngines: [LiteRtLmEngine()],
  );

  // Instantiate and initialize the background downloader service
  final downloadService = ModelDownloadService();
  await downloadService.init();

  final isDownloaded = await downloadService.isModelDownloaded();

  // Initialize dependency graph for Chat
  final ChatRepository chatRepository = ChatRepositoryImpl();
  final ChatNotifier chatNotifier = ChatNotifier(chatRepository);

  runApp(MainApp(
    downloadService: downloadService,
    chatNotifier: chatNotifier,
    startDownloaded: isDownloaded,
  ));
}

class MainApp extends StatefulWidget {
  final ModelDownloadService downloadService;
  final ChatNotifier chatNotifier;
  final bool startDownloaded;

  const MainApp({
    super.key,
    required this.downloadService,
    required this.chatNotifier,
    required this.startDownloaded,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late bool _hasModel;

  @override
  void initState() {
    super.initState();
    _hasModel = widget.startDownloaded;
  }

  void _onModelAvailable() {
    setState(() {
      _hasModel = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Axora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        useMaterial3: true,
      ),
      home: _hasModel
          ? HubScreen(chatNotifier: widget.chatNotifier)
          : ModelDownloadScreen(
              downloadService: widget.downloadService,
              onDownloadComplete: _onModelAvailable,
            ),
    );
  }
}
