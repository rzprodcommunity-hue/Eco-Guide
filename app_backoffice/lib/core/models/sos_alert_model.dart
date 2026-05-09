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
  });

  factory SosAlertModel.fromJson(Map<String, dynamic> json) {
    return SosAlertModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      message: json['message'],
      emergencyContact: json['emergencyContact'],
      isResolved: json['isResolved'] ?? false,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  String get statusLabel => isResolved ? 'Resolu' : 'Actif';
}
