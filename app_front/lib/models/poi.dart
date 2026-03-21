class Poi {
  final String id;
  final String name;
  final String type;
  final String description;
  final double latitude;
  final double longitude;
  final String? mediaUrl;
  final List<String>? additionalMediaUrls;
  final String? audioGuideUrl;
  final String? trailId;
  final bool isActive;
  final DateTime createdAt;

  Poi({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.mediaUrl,
    this.additionalMediaUrls,
    this.audioGuideUrl,
    this.trailId,
    required this.isActive,
    required this.createdAt,
  });

  String get typeDisplayName {
    switch (type) {
      case 'viewpoint':
        return 'Point de vue';
      case 'flora':
        return 'Flore';
      case 'fauna':
        return 'Faune';
      case 'historical':
        return 'Site historique';
      case 'water':
        return 'Point d\'eau';
      case 'camping':
        return 'Camping';
      case 'danger':
        return 'Zone dangereuse';
      case 'rest_area':
        return 'Aire de repos';
      case 'information':
        return 'Information';
      default:
        return type;
    }
  }

  static double _parseDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static List<String>? _parseStringList(dynamic raw) {
    if (raw is! List) return null;

    final items = raw
        .map((item) => item?.toString().trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();

    return items.isEmpty ? null : items;
  }

  factory Poi.fromJson(Map<String, dynamic> json) {
    return Poi(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      mediaUrl: json['mediaUrl'] as String?,
      additionalMediaUrls: _parseStringList(json['additionalMediaUrls']),
      audioGuideUrl: json['audioGuideUrl'] as String?,
      trailId: json['trailId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'mediaUrl': mediaUrl,
      'additionalMediaUrls': additionalMediaUrls,
      'audioGuideUrl': audioGuideUrl,
      'trailId': trailId,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
