class LocalService {
  final String id;
  final String name;
  final String category;
  final String description;
  final String? contact;
  final String? email;
  final String? website;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final List<String>? additionalImages;
  final List<String>? languages;
  final double? rating;
  final int reviewCount;
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;

  LocalService({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.contact,
    this.email,
    this.website,
    this.address,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.additionalImages,
    this.languages,
    this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.isActive,
    required this.createdAt,
  });

  String get categoryDisplayName {
    switch (category) {
      case 'guide':
        return 'Guide';
      case 'artisan':
        return 'Artisan';
      case 'accommodation':
        return 'Hebergement';
      case 'restaurant':
        return 'Restaurant';
      case 'transport':
        return 'Transport';
      case 'equipment':
        return 'Equipement';
      default:
        return category;
    }
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
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

  factory LocalService.fromJson(Map<String, dynamic> json) {
    return LocalService(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      contact: json['contact'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      address: json['address'] as String?,
        latitude: _parseNullableDouble(json['latitude']),
        longitude: _parseNullableDouble(json['longitude']),
      imageUrl: json['imageUrl'] as String?,
        additionalImages: _parseStringList(json['additionalImages']),
        languages: _parseStringList(json['languages']),
        rating: _parseNullableDouble(json['rating']),
        reviewCount: _parseInt(json['reviewCount']),
      isVerified: json['isVerified'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'contact': contact,
      'email': email,
      'website': website,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'additionalImages': additionalImages,
      'languages': languages,
      'rating': rating,
      'reviewCount': reviewCount,
      'isVerified': isVerified,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
