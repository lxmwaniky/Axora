import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/flashcard_deck.dart';
import '../../domain/repositories/flashcard_repository.dart';

class FlashcardNotifier extends ChangeNotifier {
  final FlashcardRepository _repository;
  
  List<FlashcardDeck> _decks = [];
  bool _isLoading = false;

  FlashcardNotifier(this._repository) {
    loadDecks();
  }

  List<FlashcardDeck> get decks => _decks;
  bool get isLoading => _isLoading;

  Future<String> _getModelPath() async {
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}/${AppConfig.modelFilename}';
  }

  Future<void> loadDecks() async {
    _isLoading = true;
    notifyListeners();
    
    _decks = await _repository.getDecks();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addDeck(FlashcardDeck deck) async {
    _decks.insert(0, deck);
    await _repository.saveDecks(_decks);
    notifyListeners();
  }

  Future<void> deleteDeck(String deckId) async {
    // Delete any associated attachment files
    final index = _decks.indexWhere((d) => d.id == deckId);
    if (index != -1) {
      _decks.removeAt(index);
      await _repository.saveDecks(_decks);
      notifyListeners();
    }
  }

  Future<void> updateDeck(FlashcardDeck updatedDeck) async {
    final index = _decks.indexWhere((d) => d.id == updatedDeck.id);
    if (index != -1) {
      _decks[index] = updatedDeck;
      await _repository.saveDecks(_decks);
      notifyListeners();
    }
  }

  /// Generates a new deck using the offline Gemma 4 engine in the background
  Future<void> generateDeck({
    required String title,
    required String topic,
    String? text,
    String? imagePath,
    String? pdfPath,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final modelPath = await _getModelPath();
      final newDeck = await _repository.generateDeckFromMultimodal(
        title: title,
        topic: topic,
        text: text,
        imagePath: imagePath,
        pdfPath: pdfPath,
        modelPath: modelPath,
      );
      
      _decks.insert(0, newDeck);
      await _repository.saveDecks(_decks);
    } catch (e) {
      debugPrint('[FlashcardNotifier] Error generating deck: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marks a specific card in a deck as mastered
  Future<void> toggleCardMastery(String deckId, String cardId, bool mastered) async {
    final deckIndex = _decks.indexWhere((d) => d.id == deckId);
    if (deckIndex != -1) {
      final deck = _decks[deckIndex];
      final cardIndex = deck.cards.indexWhere((c) => c.id == cardId);
      if (cardIndex != -1) {
        deck.cards[cardIndex].isMastered = mastered;
        await _repository.saveDecks(_decks);
        notifyListeners();
      }
    }
  }
}
