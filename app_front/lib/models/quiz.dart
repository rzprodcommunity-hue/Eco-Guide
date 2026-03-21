class Quiz {
  final String id;
  final String question;
  final List<String> answers;
  final int correctAnswerIndex;
  final String? explanation;
  final String? category;
  final String? imageUrl;
  final String? trailId;
  final String? poiId;
  final int points;
  final bool isActive;
  final DateTime createdAt;

  Quiz({
    required this.id,
    required this.question,
    required this.answers,
    required this.correctAnswerIndex,
    this.explanation,
    this.category,
    this.imageUrl,
    this.trailId,
    this.poiId,
    required this.points,
    required this.isActive,
    required this.createdAt,
  });

  String get categoryDisplayName {
    switch (category) {
      case 'flora':
        return 'Flore';
      case 'fauna':
        return 'Faune';
      case 'ecology':
        return 'Ecologie';
      case 'history':
        return 'Histoire';
      case 'geography':
        return 'Geographie';
      case 'safety':
        return 'Securite';
      default:
        return category ?? 'General';
    }
  }

  bool isCorrect(int selectedIndex) {
    return selectedIndex == correctAnswerIndex;
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String,
      question: json['question'] as String,
      answers: List<String>.from(json['answers'] as List),
      correctAnswerIndex: _parseInt(json['correctAnswerIndex']),
      explanation: json['explanation'] as String?,
      category: json['category'] as String?,
      imageUrl: json['imageUrl'] as String?,
      trailId: json['trailId'] as String?,
      poiId: json['poiId'] as String?,
      points: _parseInt(json['points'], fallback: 10),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answers': answers,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'category': category,
      'imageUrl': imageUrl,
      'trailId': trailId,
      'poiId': poiId,
      'points': points,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
