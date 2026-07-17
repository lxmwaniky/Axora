import 'dart:async';
import 'package:flutter/material.dart';
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
  final _formKey = GlobalKey<FormState>();

  // Loading state variables
  bool _isGenerating = false;
  String _loadingMessage = "Axora is brainstorming questions... 🧠";
  Timer? _messageTimer;
  int _messageIndex = 0;

  final List<String> _loadingMessages = [
    "Axora is brainstorming questions... 🧠",
    "Structuring 20 Q&As for active recall... 🎴",
    "Writing precise answers... 📝",
    "Assembling your offline deck... 💾",
    "Almost ready... 🚀",
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

  Future<void> _handleGenerate() async {
    if (!_formKey.currentState!.validate()) return;
    
    final topic = _topicController.text.trim();

    setState(() {
      _isGenerating = true;
    });
    _startLoadingMessages();

    try {
      await widget.notifier.generateDeck(
        title: topic, // Use the topic as the deck title
        topic: topic,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter a specific topic to generate 20 flashcards offline using Gemma.',
                    style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 32),

                  // Topic Field
                  const Text(
                    'TOPIC / SUBJECT',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.psychology_outlined, color: Colors.white30, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _topicController,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'e.g., Mitosis phases, React Hooks, World War II...',
                              hintStyle: TextStyle(color: Colors.white30),
                              border: InputBorder.none,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a topic.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

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
                ],
              ),
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
}
