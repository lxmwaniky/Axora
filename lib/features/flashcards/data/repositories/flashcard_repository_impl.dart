import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../domain/entities/flashcard.dart';
import '../../domain/entities/flashcard_deck.dart';
import '../../domain/repositories/flashcard_repository.dart';

class FlashcardRepositoryImpl implements FlashcardRepository {
  static const String _fileName = 'flashcard_decks.json';

  String _generateUuid() {
    final random = Random();
    return '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1000000)}';
  }

  Future<File> _getLocalFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }

  @override
  Future<List<FlashcardDeck>> getDecks() async {
    try {
      final file = await _getLocalFile();
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList
          .map((item) => FlashcardDeck.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[FlashcardRepository] Error getting decks: $e');
      return [];
    }
  }

  @override
  Future<void> saveDecks(List<FlashcardDeck> decks) async {
    try {
      final file = await _getLocalFile();
      final jsonList = decks.map((deck) => deck.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[FlashcardRepository] Error saving decks: $e');
    }
  }

  @override
  Future<FlashcardDeck> generateDeckFromMultimodal({
    required String title,
    required String topic,
    String? text,
    String? imagePath,
    String? pdfPath,
    required String modelPath,
  }) async {
    debugPrint('[FlashcardRepository] Generating deck from multimodal input...');

    // 1. Extract text from PDF if pdfPath is provided
    String? extractedText = text;
    if (pdfPath != null && pdfPath.isNotEmpty) {
      try {
        final pdfFile = File(pdfPath);
        final bytes = await pdfFile.readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(document);
        final pdfText = extractor.extractText();
        document.dispose();
        
        // Limit text length to prevent context overflow (Gemma 4 context is ~2048 - 8192 tokens)
        extractedText = pdfText.length > 8000 ? pdfText.substring(0, 8000) : pdfText;
        debugPrint('[FlashcardRepository] Successfully extracted ${extractedText.length} characters from PDF.');
      } catch (e) {
        debugPrint('[FlashcardRepository] Error extracting text from PDF: $e');
      }
    }

    // 2. Construct prompt instructing Gemma to generate clean JSON
    final basePrompt = '''
You are a professional offline study deck generator.
Extract and generate exactly 5 high-quality flashcards based on the provided material/topic.
Output ONLY a valid raw JSON array containing maps with "question" and "answer" keys.
Do not wrap the output in markdown code blocks (like ```json). Do not write any introduction, markdown, or chat explanations.

Example format:
[
  {"question": "Front side question?", "answer": "Back side answer."}
]

Topic: $topic
Content: ${extractedText ?? ""}
''';

    // 3. Load the active model. The model is guaranteed to be downloaded and active
    // because the user must pass the ModelDownloadScreen before reaching this feature.
    final model = await FlutterGemma.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.cpu,
      supportImage: true,
      supportAudio: true,
    );

    // 4. Create a temporary chat session
    final tempChat = await model.createChat(
      systemInstruction: "You are a precise JSON generator. Output only valid JSON arrays.",
      modelType: ModelType.gemma4,
      supportImage: true,
      supportAudio: true,
    );

    // 5. Create the multimodal message
    Message message;
    if (imagePath != null && imagePath.isNotEmpty) {
      final imageFile = File(imagePath);
      Uint8List bytes;
      if (await imageFile.exists()) {
        bytes = await imageFile.readAsBytes();
      } else {
        bytes = _getFallbackImageBytes();
      }
      bytes = await _resizeImageBytes(bytes, 384);
      message = Message.withImage(
        text: '<|image><image|>\n$basePrompt',
        imageBytes: bytes,
        isUser: true,
      );
    } else {
      message = Message.text(
        text: basePrompt,
        isUser: true,
      );
    }

    await tempChat.addQueryChunk(message);

    // 5. Gather raw token outputs
    String rawResponse = "";
    final stream = tempChat.generateChatResponseAsync();
    await for (final chunk in stream) {
      if (chunk is TextResponse) {
        rawResponse += chunk.token;
      }
    }
    await tempChat.close();

    debugPrint('[FlashcardRepository] Raw response from Gemma: \n$rawResponse');

    // 6. Sanitise and parse JSON response
    String cleanJson = rawResponse.trim();
    if (cleanJson.contains('```')) {
      final startIndex = cleanJson.indexOf('[');
      final endIndex = cleanJson.lastIndexOf(']');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        cleanJson = cleanJson.substring(startIndex, endIndex + 1);
      }
    }

    List<Flashcard> generatedCards = [];
    try {
      final List<dynamic> parsedList = jsonDecode(cleanJson);
      for (final item in parsedList) {
        if (item is Map<String, dynamic>) {
          generatedCards.add(
            Flashcard(
              id: _generateUuid(),
              question: item['question'] ?? 'Q',
              answer: item['answer'] ?? 'A',
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[FlashcardRepository] Failed to parse JSON response: $e');
      // Fallback: create mock/empty card so it doesn't fail completely
      generatedCards = [
        Flashcard(
          id: _generateUuid(),
          question: "Failed to generate card automatically. Edit me!",
          answer: "Raw model output was: ${rawResponse.substring(0, rawResponse.length > 100 ? 100 : rawResponse.length)}",
        )
      ];
    }

    return FlashcardDeck(
      id: _generateUuid(),
      title: title.trim().isEmpty ? 'Untitled Deck' : title,
      topic: topic.trim().isEmpty ? 'General' : topic,
      cards: generatedCards,
      createdAt: DateTime.now(),
    );
  }

  Uint8List _getFallbackImageBytes() {
    const base64Png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
    return base64Decode(base64Png);
  }

  Future<Uint8List> _resizeImageBytes(Uint8List originalBytes, int maxDimension) async {
    try {
      final Completer<ui.Image> completer = Completer();
      ui.decodeImageFromList(originalBytes, (ui.Image img) {
        completer.complete(img);
      });
      final ui.Image image = await completer.future;

      int width = image.width;
      int height = image.height;

      if (width > maxDimension || height > maxDimension) {
        if (width > height) {
          height = (height * maxDimension / width).round();
          width = maxDimension;
        } else {
          width = (width * maxDimension / height).round();
          height = maxDimension;
        }
      } else {
        image.dispose();
        return originalBytes;
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        paint,
      );

      final picture = recorder.endRecording();
      final resizedImage = await picture.toImage(width, height);
      final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      
      image.dispose();
      resizedImage.dispose();
      picture.dispose();

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('[ImageResize] Error resizing image: $e');
    }
    return originalBytes;
  }
}
