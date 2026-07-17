import 'flashcard.dart';

class FlashcardDeck {
  final String id;
  final String title;
  final String topic;
  final List<Flashcard> cards;
  final DateTime createdAt;

  FlashcardDeck({
    required this.id,
    required this.title,
    required this.topic,
    required this.cards,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'topic': topic,
        'cards': cards.map((c) => c.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) => FlashcardDeck(
        id: json['id'] as String,
        title: json['title'] as String,
        topic: json['topic'] as String,
        cards: (json['cards'] as List<dynamic>?)
                ?.map((c) => Flashcard.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}
