enum PoiType {
  viewpoint,
  flora,
  fauna,
  historical,
  water,
  camping,
  danger,
  rest_area,
  information,
}

class PoiModel {
  final String id;
  final String name;
  final PoiType type;
  final String description;
  final String? badge;
  final String? learnMoreUrl;
  final double latitude;
  final double longitude;
  final String? mediaUrl;
  final List<String>? additionalMediaUrls;
  final String? audioGuideUrl;
  final String? trailId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PoiModel({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    this.badge,
    this.learnMoreUrl,
    required this.latitude,
    required this.longitude,
    this.mediaUrl,
    this.additionalMediaUrls,
    this.audioGuideUrl,
    this.trailId,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory PoiModel.fromJson(Map<String, dynamic> json) {
    return PoiModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: _parseType(json['type']),
      description: json['description'] ?? '',
      badge: json['badge'],
      learnMoreUrl: json['learnMoreUrl'],
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      mediaUrl: json['mediaUrl'],
      additionalMediaUrls: json['additionalMediaUrls'] != null
          ? List<String>.from(json['additionalMediaUrls'])
          : null,
      audioGuideUrl: json['audioGuideUrl'],
      trailId: json['trailId'],
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
      'type': type.name,
      'description': description,
      'badge': badge,
      'learnMoreUrl': learnMoreUrl,
      'latitude': latitude,
      'longitude': longitude,
      'mediaUrl': mediaUrl,
      'additionalMediaUrls': additionalMediaUrls,
      'audioGuideUrl': audioGuideUrl,
      'trailId': trailId,
      'isActive': isActive,
    };
  }

  static PoiType _parseType(String? value) {
    switch (value) {
      case 'viewpoint':
        return PoiType.viewpoint;
      case 'flora':
        return PoiType.flora;
      case 'fauna':
        return PoiType.fauna;
      case 'historical':
        return PoiType.historical;
      case 'water':
        return PoiType.water;
      case 'camping':
        return PoiType.camping;
      case 'danger':
        return PoiType.danger;
      case 'rest_area':
        return PoiType.rest_area;
      case 'information':
        return PoiType.information;
      default:
        return PoiType.viewpoint;
    }
  }

  String get typeLabel {
    switch (type) {
      case PoiType.viewpoint:
        return 'Point de vue';
      case PoiType.flora:
        return 'Flore';
      case PoiType.fauna:
        return 'Faune';
      case PoiType.historical:
        return 'Historique';
      case PoiType.water:
        return 'Point d\'eau';
      case PoiType.camping:
        return 'Camping';
      case PoiType.danger:
        return 'Danger';
      case PoiType.rest_area:
        return 'Aire de repos';
      case PoiType.information:
        return 'Information';
    }
  }
}
