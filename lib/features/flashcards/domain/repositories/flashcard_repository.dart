import '../entities/flashcard_deck.dart';

abstract class FlashcardRepository {
  Future<List<FlashcardDeck>> getDecks();
  Future<void> saveDecks(List<FlashcardDeck> decks);
  
  /// Generates a flashcard deck using the offline Gemma 4 engine from text, image, or PDF input.
  Future<FlashcardDeck> generateDeckFromMultimodal({
    required String title,
    required String topic,
    String? text,
    String? imagePath,
    String? pdfPath,
    required String modelPath,
  });
}
