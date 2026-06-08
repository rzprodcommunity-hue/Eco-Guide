class SosAlertModel {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final String? message;
  final String? emergencyContact;
  final bool isResolved;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final SosUserProfile? profile;

  SosAlertModel({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.message,
    this.emergencyContact,
    required this.isResolved,
    this.resolvedAt,
    required this.createdAt,
    this.profile,
  });

  factory SosAlertModel.fromJson(Map<String, dynamic> json) {
    return SosAlertModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      message: json['message'],
      emergencyContact: json['emergencyContact'],
      isResolved: json['isResolved'] == true || json['status'] == 'resolved',
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      profile: json['profile'] is Map<String, dynamic>
          ? SosUserProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }

  String get statusLabel => isResolved ? 'Resolu' : 'Actif';
}

class SosUserProfile {
  final String id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? phone;

  SosUserProfile({
    required this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.phone,
  });

  factory SosUserProfile.fromJson(Map<String, dynamic> json) {
    return SosUserProfile(
      id: (json['id'] ?? '').toString(),
      email: json['email'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      phone: (json['phone'] ?? json['phoneNumber']) as String?,
    );
  }

  String get fullName {
    final f = firstName?.trim() ?? '';
    final l = lastName?.trim() ?? '';
    final joined = '$f $l'.trim();
    return joined.isEmpty ? (email ?? 'Utilisateur inconnu') : joined;
  }

  String get initials {
    final f = (firstName?.trim().isNotEmpty ?? false)
        ? firstName!.trim()[0].toUpperCase()
        : '';
    final l = (lastName?.trim().isNotEmpty ?? false)
        ? lastName!.trim()[0].toUpperCase()
        : '';
    final result = '$f$l';
    if (result.isNotEmpty) return result;
    if (email != null && email!.isNotEmpty) {
      return email![0].toUpperCase();
    }
    return '?';
  }
}
