enum TrailDifficulty { easy, moderate, difficult }

class TrailModel {
  final String id;
  final String name;
  final String description;
  final double distance;
  final TrailDifficulty difficulty;
  final Map<String, dynamic>? geojson;
  final int? estimatedDuration;
  final int? elevationGain;
  final List<String>? imageUrls;
  final String? region;
  final double? averageRating;
  final int? reviewCount;
  final double? startLatitude;
  final double? startLongitude;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TrailModel({
    required this.id,
    required this.name,
    required this.description,
    required this.distance,
    required this.difficulty,
    this.geojson,
    this.estimatedDuration,
    this.elevationGain,
    this.imageUrls,
    this.region,
    this.averageRating,
    this.reviewCount,
    this.startLatitude,
    this.startLongitude,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory TrailModel.fromJson(Map<String, dynamic> json) {
    return TrailModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      distance: _parseDouble(json['distance']),
      difficulty: _parseDifficulty(json['difficulty']),
      geojson: json['geojson'],
      estimatedDuration: json['estimatedDuration'],
      elevationGain: json['elevationGain'],
      imageUrls: json['imageUrls'] != null
          ? List<String>.from(json['imageUrls'])
          : null,
      region: json['region'],
        averageRating: json['averageRating'] != null ? _parseDouble(json['averageRating']) : null,
        reviewCount: json['reviewCount'] is int
          ? json['reviewCount']
          : (json['reviewCount'] is num ? (json['reviewCount'] as num).toInt() : null),
      startLatitude: json['startLatitude'] != null ? _parseDouble(json['startLatitude']) : null,
      startLongitude: json['startLongitude'] != null ? _parseDouble(json['startLongitude']) : null,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'distance': distance,
      'difficulty': difficulty.name,
      'geojson': geojson,
      'estimatedDuration': estimatedDuration,
      'elevationGain': elevationGain,
      'imageUrls': imageUrls,
      'region': region,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'isActive': isActive,
    };
  }

  static TrailDifficulty _parseDifficulty(String? value) {
    switch (value) {
      case 'easy':
        return TrailDifficulty.easy;
      case 'difficult':
        return TrailDifficulty.difficult;
      default:
        return TrailDifficulty.moderate;
    }
  }

  String get difficultyLabel {
    switch (difficulty) {
      case TrailDifficulty.easy:
        return 'Facile';
      case TrailDifficulty.moderate:
        return 'Modere';
      case TrailDifficulty.difficult:
        return 'Difficile';
    }
  }

  String get durationFormatted {
    if (estimatedDuration == null) return '-';
    final hours = estimatedDuration! ~/ 60;
    final minutes = estimatedDuration! % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }
}
