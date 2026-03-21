class DashboardStats {
  final int users;
  final int trails;
  final int pois;
  final int quizzes;
  final int localServices;
  final int activities;
  final int activeSosAlerts;

  DashboardStats({
    required this.users,
    required this.trails,
    required this.pois,
    required this.quizzes,
    required this.localServices,
    required this.activities,
    required this.activeSosAlerts,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      users: json['users'] ?? 0,
      trails: json['trails'] ?? 0,
      pois: json['pois'] ?? 0,
      quizzes: json['quizzes'] ?? 0,
      localServices: json['localServices'] ?? 0,
      activities: json['activities'] ?? 0,
      activeSosAlerts: json['activeSosAlerts'] ?? 0,
    );
  }
}

class DashboardData {
  final DashboardStats summary;
  final List<dynamic> recentActivities;

  DashboardData({
    required this.summary,
    required this.recentActivities,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      summary: DashboardStats.fromJson(json['summary'] ?? {}),
      recentActivities: json['recentActivities'] ?? [],
    );
  }
}
