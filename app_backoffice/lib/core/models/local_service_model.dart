enum ServiceCategory {
  guide,
  artisan,
  accommodation,
  restaurant,
  transport,
  equipment
}

class LocalServiceModel {
  final String id;
  final String name;
  final ServiceCategory category;
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
  final DateTime? updatedAt;

  LocalServiceModel({
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
    this.updatedAt,
  });

  factory LocalServiceModel.fromJson(Map<String, dynamic> json) {
    return LocalServiceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: _parseCategory(json['category']),
      description: json['description'] ?? '',
      contact: json['contact'],
      email: json['email'],
      website: json['website'],
      address: json['address'],
      latitude: json['latitude'] != null ? _parseDouble(json['latitude']) : null,
      longitude: json['longitude'] != null ? _parseDouble(json['longitude']) : null,
      imageUrl: json['imageUrl'],
      additionalImages: json['additionalImages'] != null
          ? List<String>.from(json['additionalImages'])
          : null,
      languages: json['languages'] != null
          ? List<String>.from(json['languages'])
          : null,
      rating: json['rating'] != null ? _parseDouble(json['rating']) : null,
      reviewCount: json['reviewCount'] ?? 0,
      isVerified: json['isVerified'] ?? false,
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
      'category': category.name,
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
      'isVerified': isVerified,
      'isActive': isActive,
    };
  }

  static ServiceCategory _parseCategory(String? value) {
    switch (value) {
      case 'guide':
        return ServiceCategory.guide;
      case 'artisan':
        return ServiceCategory.artisan;
      case 'accommodation':
        return ServiceCategory.accommodation;
      case 'restaurant':
        return ServiceCategory.restaurant;
      case 'transport':
        return ServiceCategory.transport;
      case 'equipment':
        return ServiceCategory.equipment;
      default:
        return ServiceCategory.guide;
    }
  }

  String get categoryLabel {
    switch (category) {
      case ServiceCategory.guide:
        return 'Guide';
      case ServiceCategory.artisan:
        return 'Artisan';
      case ServiceCategory.accommodation:
        return 'Hebergement';
      case ServiceCategory.restaurant:
        return 'Restaurant';
      case ServiceCategory.transport:
        return 'Transport';
      case ServiceCategory.equipment:
        return 'Equipement';
    }
  }
}
