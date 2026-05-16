import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    if (kIsWeb) {
      await _loginWithGoogleWeb();
      return;
    }

    await _supabase.auth.signInWithOAuth(
      supabase.OAuthProvider.google,
      redirectTo: _oauthRedirectTo(),
      scopes: 'email profile',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  static Future<void> _loginWithGoogleWeb() async {
    final clientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
    if (clientId == null || clientId.isEmpty) {
      throw ApiException(
        'GOOGLE_WEB_CLIENT_ID manquant dans .env',
        500,
      );
    }

    final googleSignIn = GoogleSignIn(
      clientId: clientId,
      scopes: const ['email', 'profile', 'openid'],
    );

    final account = await googleSignIn.signIn();
    if (account == null) {
      throw ApiException('Connexion Google annulee', 401);
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;

    if (idToken == null) {
      throw ApiException('Google n\'a pas retourne d\'ID token', 401);
    }

    await _supabase.auth.signInWithIdToken(
      provider: supabase.OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
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

    Map<String, dynamic>? profile;
    try {
      profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();
    } catch (_) {
      // profiles table may not exist — fall back to auth metadata
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
      // Default to 'admin' for backoffice — all authenticated users are admins
      'role': profile?['role'] ?? 'admin',
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
    try {
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
    } catch (_) {
      // profiles table may not be set up yet — continue without syncing
    }
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
