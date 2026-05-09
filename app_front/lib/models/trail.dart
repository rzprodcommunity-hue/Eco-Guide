class Trail {
  final String id;
  final String name;
  final String description;
  final double distance;
  final String difficulty;
  final int? estimatedDuration;
  final double? elevationGain;
  final List<String>? imageUrls;
  final String? region;
  final double? averageRating;
  final int? reviewCount;
  final double? startLatitude;
  final double? startLongitude;
  final Map<String, dynamic>? geojson;
  final bool isActive;
  final DateTime createdAt;

  Trail({
    required this.id,
    required this.name,
    required this.description,
    required this.distance,
    required this.difficulty,
    this.estimatedDuration,
    this.elevationGain,
    this.imageUrls,
    this.region,
    this.averageRating,
    this.reviewCount,
    this.startLatitude,
    this.startLongitude,
    this.geojson,
    required this.isActive,
    required this.createdAt,
  });

  String get durationText {
    if (estimatedDuration == null) return 'N/A';
    final hours = estimatedDuration! ~/ 60;
    final minutes = estimatedDuration! % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}min';
    } else if (hours > 0) {
      return '${hours}h';
    }
    return '${minutes}min';
  }

  String get distanceText {
    if (distance < 1) {
      return '${(distance * 1000).toInt()}m';
    }
    return '${distance.toStringAsFixed(1)}km';
  }

  static double _parseDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<String>? _parseImageUrls(dynamic raw) {
    if (raw is! List) return null;

    final urls = raw
        .map((item) {
          final value = item?.toString().trim();
          if (value == null || value.isEmpty) return null;

          // Handles malformed values like {"https://..."} from seed output.
          final cleaned = value
              .replaceAll('{', '')
              .replaceAll('}', '')
              .replaceAll('"', '')
              .trim();

          if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
            return cleaned;
          }
          return null;
        })
        .whereType<String>()
        .toList();

    return urls.isEmpty ? null : urls;
  }

  factory Trail.fromJson(Map<String, dynamic> json) {
    return Trail(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      distance: _parseDouble(json['distance']),
      difficulty: json['difficulty'] as String,
      estimatedDuration: _parseNullableInt(json['estimatedDuration']),
      elevationGain: _parseNullableDouble(json['elevationGain']),
      imageUrls: _parseImageUrls(json['imageUrls']),
      region: json['region'] as String?,
      averageRating: _parseNullableDouble(json['averageRating']),
      reviewCount: _parseNullableInt(json['reviewCount']),
      startLatitude: _parseNullableDouble(json['startLatitude']),
      startLongitude: _parseNullableDouble(json['startLongitude']),
      geojson: json['geojson'] as Map<String, dynamic>?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'distance': distance,
      'difficulty': difficulty,
      'estimatedDuration': estimatedDuration,
      'elevationGain': elevationGain,
      'imageUrls': imageUrls,
      'region': region,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'geojson': geojson,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
