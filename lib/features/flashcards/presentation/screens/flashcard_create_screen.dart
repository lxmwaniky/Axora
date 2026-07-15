import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../state/flashcard_notifier.dart';

class FlashcardCreateScreen extends StatefulWidget {
  final FlashcardNotifier notifier;

  const FlashcardCreateScreen({super.key, required this.notifier});

  @override
  State<FlashcardCreateScreen> createState() => _FlashcardCreateScreenState();
}

class _FlashcardCreateScreenState extends State<FlashcardCreateScreen> {
  final _topicController = TextEditingController();
  
  String? _selectedFilePath;
  String? _selectedFileName;
  String? _selectedFileType; // 'pdf' or 'image'
  bool _isPickingFile = false;

  // Loading state variables
  bool _isGenerating = false;
  String _loadingMessage = "Axora is scanning your materials... 📝";
  Timer? _messageTimer;
  int _messageIndex = 0;

  final List<String> _loadingMessages = [
    "Axora is scanning your materials... 📝",
    "Extracting key learning concepts... 🧠",
    "Formulating question & answer pairs... 🎴",
    "Structuring your deck... 💾",
    "Polishing cards for active recall... 🚀",
  ];

  @override
  void dispose() {
    _topicController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  void _startLoadingMessages() {
    _messageIndex = 0;
    setState(() {
      _loadingMessage = _loadingMessages[_messageIndex];
    });
    _messageTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _isGenerating) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _loadingMessages.length;
          _loadingMessage = _loadingMessages[_messageIndex];
        });
      }
    });
  }

  Future<void> _pickFile() async {
    if (_isPickingFile) return;
    setState(() {
      _isPickingFile = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        final ext = name.split('.').last.toLowerCase();
        
        setState(() {
          _selectedFilePath = path;
          _selectedFileName = name;
          _selectedFileType = (ext == 'pdf') ? 'pdf' : 'image';
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceLight,
            content: Text('Failed to pick file: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  Future<void> _handleGenerate() async {
    final topic = _topicController.text.trim();

    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF or image file first.')),
      );
      return;
    }

    // Default title to the filename without extension
    final String finalTitle = _selectedFileName != null
        ? _selectedFileName!.split('.').first
        : 'Study Deck';
        
    final String finalTopic = topic.isEmpty ? 'General Study' : topic;

    setState(() {
      _isGenerating = true;
    });
    _startLoadingMessages();

    try {
      await widget.notifier.generateDeck(
        title: finalTitle,
        topic: finalTopic,
        text: null,
        imagePath: _selectedFileType == 'image' ? _selectedFilePath : null,
        pdfPath: _selectedFileType == 'pdf' ? _selectedFilePath : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Deck generated successfully!'),
          ),
        );
        Navigator.pop(context); // Return to Lounge
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to generate deck: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        _messageTimer?.cancel();
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'AI Deck Builder',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Upload study guides, slides, or textbook photos to build flashcards.',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Upload Area
                _buildSectionHeader('STUDY GUIDE OR PHOTO'),
                const SizedBox(height: 8),
                _buildUploadBox(),
                const SizedBox(height: 24),

                // Topic Field (Optional)
                _buildSectionHeader('SUBJECT / SPECIFIC FOCUS (OPTIONAL)'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _topicController,
                  hintText: 'e.g., Mitosis phases, React hooks, Heart ventricles...',
                  icon: Icons.topic_rounded,
                ),
                const SizedBox(height: 40),

                // Generate Button
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _handleGenerate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Generate Deck',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Loading overlay
          if (_isGenerating)
            Container(
              color: Colors.black87,
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
                        strokeWidth: 4,
                      ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _loadingMessage,
                          key: ValueKey<String>(_loadingMessage),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white30, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.white30),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBox() {
    final hasFile = _selectedFilePath != null;

    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasFile ? const Color(0xFFEC4899) : Colors.white10,
            style: hasFile ? BorderStyle.solid : BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!hasFile) ...[
                  const Icon(
                    Icons.cloud_upload_outlined,
                    color: Colors.white38,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select PDF or study image',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Supports PDF, PNG, JPG, JPEG',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ] else ...[
                  Icon(
                    _selectedFileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                    color: const Color(0xFFEC4899),
                    size: 44,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFileName ?? 'Selected File',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to replace file',
                    style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
