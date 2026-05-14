import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../core/constants/app_constants.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _guestToken = 'guest-token';

  final ApiClient _apiClient;
  late final AuthService _authService;

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthProvider(this._apiClient) {
    _authService = AuthService(_apiClient);
    _loadStoredAuth();
    if (_isSupabaseInitialized) {
      _listenToSupabaseAuth();
    }
  }

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isDemoUser => _token == _guestToken;
  bool get _isSupabaseInitialized {
    try {
      supabase.Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadStoredAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final isGuestMode = prefs.getBool(AppConstants.guestModeKey) ?? false;
      final storedToken = prefs.getString(AppConstants.tokenKey);
      final storedUserJson = prefs.getString(AppConstants.userKey);

      // 1. Load from local cache instantly if available
      if (storedToken != null && storedUserJson != null) {
        _token = storedToken;
        _user = User.fromJson(
          jsonDecode(storedUserJson) as Map<String, dynamic>,
        );
        if (!isGuestMode) _apiClient.setToken(_token);
        _isLoading = false;
        notifyListeners();

        // 2. Verify with Supabase in background (with timeout, non-blocking)
        if (_isSupabaseInitialized && !isGuestMode) {
          _authService
              .currentAuthResponse()
              .timeout(const Duration(seconds: 4))
              .then((supabaseAuth) async {
                if (supabaseAuth != null) {
                  await _saveAuth(supabaseAuth.accessToken, supabaseAuth.user);
                }
              })
              .catchError((_) {});
        }
        return;
      }

      // 3. No local cache — try Supabase with timeout
      if (_isSupabaseInitialized) {
        try {
          final supabaseAuth = await _authService
              .currentAuthResponse()
              .timeout(const Duration(seconds: 5));
          if (supabaseAuth != null) {
            await _saveAuth(supabaseAuth.accessToken, supabaseAuth.user);
          }
        } catch (_) {
          // Network issue — show login screen
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _listenToSupabaseAuth() {
    _authSubscription = supabase.Supabase.instance.client.auth.onAuthStateChange
        .listen((data) async {
          final event = data.event;
          final session = data.session;

          if (event == supabase.AuthChangeEvent.signedOut || session == null) {
            if (isDemoUser) {
              notifyListeners();
              return;
            }
            await _clearStoredAuth();
            notifyListeners();
            return;
          }

          if (event == supabase.AuthChangeEvent.signedIn ||
              event == supabase.AuthChangeEvent.initialSession ||
              event == supabase.AuthChangeEvent.tokenRefreshed ||
              event == supabase.AuthChangeEvent.userUpdated) {
            try {
              final response = await _authService.currentAuthResponse();
              if (response == null) return;
              await _saveAuth(response.accessToken, response.user);
              notifyListeners();
            } catch (e) {
              _error = e.toString();
              notifyListeners();
            }
          }
        });
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );
      await _clearGuestMode();
      await _saveAuth(response.accessToken, response.user);
      return true;
    } catch (e) {
      _error = _friendlyError(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      await _clearGuestMode();
      await _saveAuth(response.accessToken, response.user);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.loginWithGoogle();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> continueAsGuest() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final guestUser = User(
        id: 'guest-user',
        email: 'guest@eco-guide.local',
        role: 'guest',
        firstName: 'Guest',
        lastName: null,
        avatarUrl: null,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.guestModeKey, true);
      await _saveAuth(_guestToken, guestUser);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveAuth(String token, User user) async {
    _token = token;
    _user = user;
    _apiClient.setToken(token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    if (_isSupabaseInitialized) {
      await supabase.Supabase.instance.client.auth.signOut();
    }
    await _clearStoredAuth();
    notifyListeners();
  }

  Future<void> _clearStoredAuth() async {
    _token = null;
    _user = null;
    _apiClient.setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    await prefs.remove(AppConstants.guestModeKey);
  }

  Future<void> _clearGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.guestModeKey);
  }

  Future<void> refreshProfile() async {
    if (_token == null) return;

    try {
      final user = await _authService.getProfile();
      _user = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendlyError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('email not confirmed') || msg.contains('email_not_confirmed')) {
      return 'Votre email n\'est pas confirmé. Vérifiez votre boîte mail et cliquez sur le lien de confirmation.';
    }
    if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (msg.contains('user not found')) {
      return 'Aucun compte trouvé avec cet email.';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'Problème de connexion réseau. Vérifiez votre internet.';
    }
    return raw;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
