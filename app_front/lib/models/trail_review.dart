class TrailReview {
  final String id;
  final String trailId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final double rating;
  final String text;
  final DateTime createdAt;

  TrailReview({
    required this.id,
    required this.trailId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.rating,
    required this.text,
    required this.createdAt,
  });

  String get initials {
    final words = userName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return 'U';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words.first[0] + words.last[0]).toUpperCase();
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'il y a 1 jour';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} jours';
    if (diff.inDays < 30) return 'il y a ${(diff.inDays / 7).floor()} semaine(s)';
    if (diff.inDays < 365) return 'il y a ${(diff.inDays / 30).floor()} mois';
    return 'il y a ${(diff.inDays / 365).floor()} an(s)';
  }

  factory TrailReview.fromJson(Map<String, dynamic> json) {
    return TrailReview(
      id: json['id'] as String,
      trailId: json['trail_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'Anonyme',
      userAvatar: json['user_avatar'] as String?,
      rating: (json['rating'] as num).toDouble(),
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'trail_id': trailId,
        'user_id': userId,
        'user_name': userName,
        if (userAvatar != null) 'user_avatar': userAvatar,
        'rating': rating,
        'text': text,
      };
}
