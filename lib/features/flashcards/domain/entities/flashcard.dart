class Flashcard {
  final String id;
  final String question;
  final String answer;
  bool isMastered;

  Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    this.isMastered = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'answer': answer,
        'isMastered': isMastered,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'] as String,
        question: json['question'] as String,
        answer: json['answer'] as String,
        isMastered: json['isMastered'] as bool? ?? false,
      );
}
