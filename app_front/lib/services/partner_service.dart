import 'package:supabase_flutter/supabase_flutter.dart';

class PartnerRequest {
  final String id;
  final String userId;
  final String businessName;
  final String category;
  final String description;
  final String phone;
  final String email;
  final String? address;
  final String status; // pending | approved | rejected
  final DateTime createdAt;

  const PartnerRequest({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.category,
    required this.description,
    required this.phone,
    required this.email,
    this.address,
    required this.status,
    required this.createdAt,
  });

  factory PartnerRequest.fromJson(Map<String, dynamic> j) => PartnerRequest(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        businessName: j['business_name'] as String,
        category: j['category'] as String,
        description: j['description'] as String,
        phone: j['phone'] as String,
        email: j['email'] as String,
        address: j['address'] as String?,
        status: j['status'] as String? ?? 'pending',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class PartnerService {
  static final _supabase = Supabase.instance.client;
  static const _table = 'partner_requests';

  static Future<PartnerRequest> submit({
    required String businessName,
    required String category,
    required String description,
    required String phone,
    required String email,
    String? address,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    final inserted = await _supabase
        .from(_table)
        .insert({
          if (userId != null) 'user_id': userId,
          'business_name': businessName,
          'category': category,
          'description': description,
          'phone': phone,
          'email': email,
          'address': address?.isNotEmpty == true ? address : null,
          'status': 'pending',
        })
        .select()
        .single();

    return PartnerRequest.fromJson(inserted);
  }

  static Future<PartnerRequest?> getMyRequest() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _supabase
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return PartnerRequest.fromJson(data);
  }
}
