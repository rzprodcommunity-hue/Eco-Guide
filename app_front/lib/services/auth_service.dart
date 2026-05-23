import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:url_launcher/url_launcher.dart';

import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  supabase.SupabaseClient get _supabase => supabase.Supabase.instance.client;

  AuthService(ApiClient client);

  Future<AuthResponse> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final metadata = <String, dynamic>{};
    if (firstName != null) metadata['firstName'] = firstName;
    if (lastName != null) metadata['lastName'] = lastName;

    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );
    final authUser = response.user;
    if (authUser == null) {
      throw const FormatException('Supabase did not return a user');
    }

    final profile = await _upsertProfile(authUser, firstName, lastName);
    return AuthResponse(
      accessToken: response.session?.accessToken ?? '',
      user: User.fromJson(profile),
    );
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final authUser = response.user;
    if (authUser == null) {
      throw const FormatException('Invalid Supabase auth response');
    }

    return AuthResponse(
      accessToken: response.session?.accessToken ?? '',
      user: await _profileForUser(authUser),
    );
  }

  Future<void> loginWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      supabase.OAuthProvider.google,
      redirectTo: _oauthRedirectTo(),
      scopes: 'email profile',
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  Future<void> loginWithApple() async {
    await _supabase.auth.signInWithOAuth(
      supabase.OAuthProvider.apple,
      redirectTo: _oauthRedirectTo(),
      scopes: 'email name',
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  Future<AuthResponse?> currentAuthResponse() async {
    final session = _supabase.auth.currentSession;
    final authUser = session?.user ?? _supabase.auth.currentUser;
    if (session == null || authUser == null) return null;

    return AuthResponse(
      accessToken: session.accessToken,
      user: await _profileForUser(authUser),
    );
  }

  Future<User> getProfile() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      throw const FormatException('No active Supabase session');
    }
    final response = await _profileForUser(authUser);
    return response;
  }

  Future<Map<String, dynamic>> _upsertProfile(
    supabase.User authUser,
    String? firstName,
    String? lastName,
  ) async {
    await _syncProfile(authUser, firstName: firstName, lastName: lastName);
    return _profileMap(authUser, syncProfile: false);
  }

  Future<void> _syncProfile(
    supabase.User authUser, {
    String? firstName,
    String? lastName,
  }) async {
    try {
      final metadata = authUser.userMetadata ?? {};
      final names = _namesFromAuth(authUser, firstName, lastName);

      await _supabase.from('profiles').upsert({
        'id': authUser.id,
        'email': authUser.email ?? '',
        if (names.$1 != null) 'firstName': names.$1,
        if (names.$2 != null) 'lastName': names.$2,
        if (metadata['avatar_url'] != null || metadata['picture'] != null)
          'avatarUrl': metadata['avatar_url'] ?? metadata['picture'],
      });
    } catch (_) {
      // Ignore sync failures — user data from auth token is used as fallback
    }
  }

  Future<User> _profileForUser(supabase.User authUser) async {
    final response = await _profileMap(authUser);
    return User.fromJson(response);
  }

  Future<Map<String, dynamic>> _profileMap(
    supabase.User authUser, {
    bool syncProfile = true,
  }) async {
    if (syncProfile) {
      await _syncProfile(authUser);
    }

    Map<String, dynamic>? profile;
    try {
      profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();
    } catch (_) {
      profile = null;
    }

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
    };
  }

  String? _oauthRedirectTo() {
    final configured = dotenv.env['SUPABASE_AUTH_REDIRECT_URL']?.trim();
    if (configured != null && configured.isNotEmpty) {
      if (!kIsWeb || configured.startsWith('http')) return configured;
    }
    return kIsWeb ? null : 'io.supabase.ecoguide://login-callback/';
  }

  (String?, String?) _namesFromAuth(
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

class AuthResponse {
  final String accessToken;
  final User user;

  AuthResponse({required this.accessToken, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    final token = payload['access_token'] ?? payload['accessToken'];
    final userJson = payload['user'];

    if (token is! String || userJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid auth response format');
    }

    return AuthResponse(accessToken: token, user: User.fromJson(userJson));
  }
}
