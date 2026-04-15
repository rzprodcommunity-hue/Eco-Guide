class Activity {
  final String id;
  final String userId;
  final String type;
  final String? trailId;
  final String? poiId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  Activity({
    required this.id,
    required this.userId,
    required this.type,
    this.trailId,
    this.poiId,
    this.metadata,
    required this.createdAt,
  });

  String get typeDisplayName {
    switch (type) {
      case 'trail_started':
        return 'Randonnee commencee';
      case 'trail_completed':
        return 'Randonnee terminee';
      case 'poi_visited':
        return 'Point d\'interet visite';
      case 'quiz_answered':
        return 'Quiz repondu';
      case 'download':
        return 'Telechargement';
      default:
        return type;
    }
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: json['type'] as String,
      trailId: json['trailId'] as String?,
      poiId: json['poiId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'trailId': trailId,
      'poiId': poiId,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class UserStats {
  final int totalTrailsStarted;
  final int totalTrailsCompleted;
  final int totalPoisVisited;
  final int totalQuizzesAnswered;
  final double totalDistance;
  final int totalDuration;

  UserStats({
    required this.totalTrailsStarted,
    required this.totalTrailsCompleted,
    required this.totalPoisVisited,
    required this.totalQuizzesAnswered,
    required this.totalDistance,
    required this.totalDuration,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalTrailsStarted: json['totalTrailsStarted'] as int? ?? 0,
      totalTrailsCompleted: json['totalTrailsCompleted'] as int? ?? 0,
      totalPoisVisited: json['totalPoisVisited'] as int? ?? 0,
      totalQuizzesAnswered: json['totalQuizzesAnswered'] as int? ?? 0,
      totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0.0,
      totalDuration: json['totalDuration'] as int? ?? 0,
    );
  }

  String get durationText {
    final hours = totalDuration ~/ 3600;
    final minutes = (totalDuration % 3600) ~/ 60;
    return '${hours}h ${minutes}min';
  }

  String get distanceText {
    if (totalDistance < 1) {
      return '${(totalDistance * 1000).toInt()}m';
    }
    return '${totalDistance.toStringAsFixed(1)}km';
  }
}
