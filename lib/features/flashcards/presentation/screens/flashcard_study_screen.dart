import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/flashcard_deck.dart';
import '../widgets/flip_card_widget.dart';
import '../state/flashcard_notifier.dart';

class FlashcardStudyScreen extends StatefulWidget {
  final FlashcardDeck deck;
  final FlashcardNotifier notifier;

  const FlashcardStudyScreen({
    super.key,
    required this.deck,
    required this.notifier,
  });

  @override
  State<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends State<FlashcardStudyScreen> {
  int _currentIndex = 0;
  final List<String> _masteredCardIds = [];
  final List<String> _failedCardIds = [];

  bool _isFinished = false;

  void _markMastered() {
    final cardId = widget.deck.cards[_currentIndex].id;
    if (!_masteredCardIds.contains(cardId)) {
      _masteredCardIds.add(cardId);
    }
    _failedCardIds.remove(cardId);
    
    // Save to global notifier state
    widget.notifier.toggleCardMastery(widget.deck.id, cardId, true);

    _nextCard();
  }

  void _markLearning() {
    final cardId = widget.deck.cards[_currentIndex].id;
    if (!_failedCardIds.contains(cardId)) {
      _failedCardIds.add(cardId);
    }
    _masteredCardIds.remove(cardId);

    // Save to global notifier state
    widget.notifier.toggleCardMastery(widget.deck.id, cardId, false);

    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex < widget.deck.cards.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      setState(() {
        _isFinished = true;
      });
    }
  }

  void _restartStudy() {
    // Reset all cards in this deck to unmastered
    for (final card in widget.deck.cards) {
      widget.notifier.toggleCardMastery(widget.deck.id, card.id, false);
    }
    
    setState(() {
      _currentIndex = 0;
      _masteredCardIds.clear();
      _failedCardIds.clear();
      _isFinished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deck.cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(widget.deck.title)),
        body: const Center(child: Text('This deck has no cards.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.deck.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              widget.deck.topic,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _isFinished ? _buildSummaryScreen() : _buildStudyScreen(),
        ),
      ),
    );
  }

  Widget _buildStudyScreen() {
    final currentCard = widget.deck.cards[_currentIndex];
    final progress = (_currentIndex + 1) / widget.deck.cards.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Card ${_currentIndex + 1} of ${widget.deck.cards.length}',
              style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '${(_masteredCardIds.length)} mastered',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 40),

        // Flip Card Widget
        Expanded(
          child: FlipCardWidget(
            frontText: currentCard.question,
            backText: currentCard.answer,
          ),
        ),

        const SizedBox(height: 40),

        // Study Feedback Buttons
        Row(
          children: [
            // Still Learning Button
            Expanded(
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withAlpha(80), width: 1.5),
                  color: Colors.redAccent.withAlpha(20),
                ),
                child: TextButton.icon(
                  onPressed: _markLearning,
                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                  label: const Text(
                    'Still Learning',
                    style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),

            // Mastered Button
            Expanded(
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _markMastered,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  label: const Text(
                    'Mastered',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSummaryScreen() {
    final int totalCards = widget.deck.cards.length;
    final int masteredCount = _masteredCardIds.length;
    final double masteryRate = totalCards > 0 ? (masteredCount / totalCards) : 0;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Circular Mastery Ring
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: masteryRate,
                      strokeWidth: 10,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(masteryRate * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Mastered',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            const Text(
              'Session Complete! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You mastered $masteredCount out of $totalCards cards in this deck.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const SizedBox(height: 48),

            // Restart Button
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: TextButton.icon(
                onPressed: _restartStudy,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  'Restart Study Session',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Return Button
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text(
                  'Back to Lounge',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
