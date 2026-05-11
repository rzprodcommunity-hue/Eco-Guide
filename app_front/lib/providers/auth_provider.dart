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
      if (_isSupabaseInitialized) {
        final supabaseAuth = await _authService.currentAuthResponse();
        if (supabaseAuth != null) {
          await _saveAuth(supabaseAuth.accessToken, supabaseAuth.user);
          return;
        }
      }

      final isGuestMode = prefs.getBool(AppConstants.guestModeKey) ?? false;

      final storedToken = prefs.getString(AppConstants.tokenKey);
      final storedUserJson = prefs.getString(AppConstants.userKey);

      if (isGuestMode && storedToken != null && storedUserJson != null) {
        _token = storedToken;
        _user = User.fromJson(
          jsonDecode(storedUserJson) as Map<String, dynamic>,
        );
        return;
      }

      if (storedToken != null && storedUserJson != null) {
        _token = storedToken;
        _user = User.fromJson(
          jsonDecode(storedUserJson) as Map<String, dynamic>,
        );
        _apiClient.setToken(_token);
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
      _error = e.toString();
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

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
