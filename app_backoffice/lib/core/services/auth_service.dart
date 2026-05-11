import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:url_launcher/url_launcher.dart';

import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static supabase.SupabaseClient get _supabase =>
      supabase.Supabase.instance.client;

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final authUser = response.user;
    if (authUser == null) {
      throw ApiException('Invalid Supabase auth response', 401);
    }

    final profile = await _profileMap(authUser);
    await ApiService.saveToken(response.session?.accessToken ?? '');

    return {
      'accessToken': response.session?.accessToken ?? '',
      'user': profile,
    };
  }

  static Future<void> loginWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      supabase.OAuthProvider.google,
      redirectTo: _oauthRedirectTo(),
      scopes: 'email profile',
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  static Future<Map<String, dynamic>?> currentAuthResponse() async {
    final session = _supabase.auth.currentSession;
    final authUser = session?.user ?? _supabase.auth.currentUser;
    if (session == null || authUser == null) return null;

    await ApiService.saveToken(session.accessToken);
    return {
      'accessToken': session.accessToken,
      'user': await _profileMap(authUser),
    };
  }

  static Future<void> logout() async {
    await _supabase.auth.signOut();
    await ApiService.clearToken();
  }

  static Future<UserModel> getProfile() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) throw ApiException('Non autorise', 401);
    return UserModel.fromJson(await _profileMap(authUser));
  }

  static Future<bool> isAuthenticated() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return false;

    try {
      await getProfile();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  static Future<Map<String, dynamic>> _profileMap(
    supabase.User authUser,
  ) async {
    await _syncProfile(authUser);

    final profile = await _supabase
        .from('profiles')
        .select()
        .eq('id', authUser.id)
        .maybeSingle();

    final names = _namesFromAuth(
      authUser,
      profile?['firstName'] as String?,
      profile?['lastName'] as String?,
    );
    final metadata = authUser.userMetadata ?? {};

    return {
      'id': authUser.id,
      'email': authUser.email ?? profile?['email'] ?? '',
      'role': profile?['role'] ?? 'user',
      'firstName': names.$1,
      'lastName': names.$2,
      'avatarUrl':
          profile?['avatarUrl'] ??
          metadata['avatar_url'] ??
          metadata['picture'],
      'isActive': profile?['isActive'] ?? true,
      'createdAt': profile?['createdAt'] ?? DateTime.now().toIso8601String(),
      'updatedAt': profile?['updatedAt'],
    };
  }

  static Future<void> _syncProfile(supabase.User authUser) async {
    final metadata = authUser.userMetadata ?? {};
    final names = _namesFromAuth(authUser, null, null);

    await _supabase.from('profiles').upsert({
      'id': authUser.id,
      'email': authUser.email ?? '',
      if (names.$1 != null) 'firstName': names.$1,
      if (names.$2 != null) 'lastName': names.$2,
      if (metadata['avatar_url'] != null || metadata['picture'] != null)
        'avatarUrl': metadata['avatar_url'] ?? metadata['picture'],
    });
  }

  static String? _oauthRedirectTo() {
    final configured = dotenv.env['SUPABASE_AUTH_REDIRECT_URL']?.trim();
    if (configured != null && configured.isNotEmpty) {
      if (!kIsWeb || configured.startsWith('http')) return configured;
    }
    return kIsWeb ? null : 'io.supabase.ecoguide.admin://login-callback/';
  }

  static (String?, String?) _namesFromAuth(
    supabase.User authUser,
    String? firstName,
    String? lastName,
  ) {
    if (firstName != null || lastName != null) return (firstName, lastName);

    final metadata = authUser.userMetadata ?? {};
    final givenName = metadata['given_name'] as String?;
    final familyName = metadata['family_name'] as String?;
    if (givenName != null || familyName != null) {
      return (givenName, familyName);
    }

    final fullName =
        metadata['full_name'] as String? ?? metadata['name'] as String?;
    if (fullName == null || fullName.trim().isEmpty) return (null, null);

    final parts = fullName.trim().split(RegExp(r'\s+'));
    return (
      parts.isNotEmpty ? parts.first : null,
      parts.length > 1 ? parts.sublist(1).join(' ') : null,
    );
  }
}
