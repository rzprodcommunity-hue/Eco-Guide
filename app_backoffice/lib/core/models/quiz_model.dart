enum QuizCategory { flora, fauna, ecology, history, geography, safety }

class QuizModel {
  final String id;
  final String question;
  final List<String> answers;
  final int correctAnswerIndex;
  final String? explanation;
  final QuizCategory? category;
  final String? imageUrl;
  final String? trailId;
  final String? poiId;
  final int points;
  final bool isActive;
  final DateTime createdAt;

  QuizModel({
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

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      answers: json['answers'] != null
          ? List<String>.from(json['answers'])
          : [],
      correctAnswerIndex: json['correctAnswerIndex'] ?? 0,
      explanation: json['explanation'],
      category: _parseCategory(json['category']),
      imageUrl: json['imageUrl'],
      trailId: json['trailId'],
      poiId: json['poiId'],
      points: json['points'] ?? 10,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answers': answers,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'category': category?.name,
      'imageUrl': imageUrl,
      'trailId': trailId,
      'poiId': poiId,
      'points': points,
      'isActive': isActive,
    };
  }

  static QuizCategory? _parseCategory(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'flora':
        return QuizCategory.flora;
      case 'fauna':
        return QuizCategory.fauna;
      case 'ecology':
        return QuizCategory.ecology;
      case 'history':
        return QuizCategory.history;
      case 'geography':
        return QuizCategory.geography;
      case 'safety':
        return QuizCategory.safety;
      default:
        return null;
    }
  }

  String get categoryLabel {
    switch (category) {
      case QuizCategory.flora:
        return 'Flore';
      case QuizCategory.fauna:
        return 'Faune';
      case QuizCategory.ecology:
        return 'Ecologie';
      case QuizCategory.history:
        return 'Histoire';
      case QuizCategory.geography:
        return 'Geographie';
      case QuizCategory.safety:
        return 'Securite';
      case null:
        return '-';
    }
  }
}
