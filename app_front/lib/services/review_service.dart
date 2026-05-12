import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trail_review.dart';

class ReviewService {
  static final _supabase = Supabase.instance.client;
  static const _table = 'trail_reviews';

  static Future<List<TrailReview>> getReviews(String trailId) async {
    final data = await _supabase
        .from(_table)
        .select()
        .eq('trail_id', trailId)
        .order('created_at', ascending: false);

    return data
        .map((e) => TrailReview.fromJson(e))
        .toList();
  }

  static Future<TrailReview> addReview({
    required String trailId,
    required String userId,
    required String userName,
    String? userAvatar,
    required double rating,
    required String text,
  }) async {
    final inserted = await _supabase
        .from(_table)
        .insert({
          'trail_id': trailId,
          'user_id': userId,
          'user_name': userName,
          'user_avatar': userAvatar,
          'rating': rating,
          'text': text,
        })
        .select()
        .single();

    return TrailReview.fromJson(inserted);
  }
}
