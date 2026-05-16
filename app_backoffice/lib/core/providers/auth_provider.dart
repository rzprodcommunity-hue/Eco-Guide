import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  // Static admin credentials — the only login accepted by the backoffice.
  // Change these two constants if you need to rotate the password.
  static const String _adminEmail = 'admin@ecoguide.com';
  static const String _adminPassword = 'EcoAdmin2026!';

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthProvider() {
    _listenToSupabaseAuth();
  }

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await AuthService.currentAuthResponse();
      if (response != null) {
        await _applyAuthResponse(response);
      } else if (await AuthService.isAuthenticated()) {
        final profile = await AuthService.getProfile();
        if (profile.isAdmin) {
          _user = profile;
        } else {
          await AuthService.logout();
          _user = null;
        }
      }
    } catch (e) {
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Small delay so the login button shows a spinner — purely cosmetic.
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final emailMatches =
        email.trim().toLowerCase() == _adminEmail.toLowerCase();
    final passwordMatches = password == _adminPassword;

    if (!emailMatches || !passwordMatches) {
      _error = 'Email ou mot de passe incorrect.';
      _user = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _user = UserModel(
      id: 'static-admin',
      email: _adminEmail,
      role: 'admin',
      firstName: 'Admin',
      lastName: null,
      avatarUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
    );
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AuthService.loginWithGoogle();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void bypassAuth() {
    _user = UserModel(
      id: 'bypass',
      email: 'admin@ecoguide.local',
      role: 'admin',
      firstName: 'Admin',
      lastName: null,
      avatarUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
    );
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  void _listenToSupabaseAuth() {
    _authSubscription = supabase.Supabase.instance.client.auth.onAuthStateChange
        .listen((data) async {
          final event = data.event;
          final session = data.session;

          if (event == supabase.AuthChangeEvent.signedOut || session == null) {
            _user = null;
            notifyListeners();
            return;
          }

          if (event == supabase.AuthChangeEvent.signedIn ||
              event == supabase.AuthChangeEvent.initialSession ||
              event == supabase.AuthChangeEvent.tokenRefreshed ||
              event == supabase.AuthChangeEvent.userUpdated) {
            try {
              final response = await AuthService.currentAuthResponse();
              if (response == null) return;
              await _applyAuthResponse(response);
              notifyListeners();
            } catch (e) {
              _error = e.toString();
              notifyListeners();
            }
          }
        });
  }

  Future<void> _applyAuthResponse(Map<String, dynamic> response) async {
    final candidate = UserModel.fromJson(response['user']);
    if (!candidate.isAdmin) {
      _error = 'Acces reserve aux administrateurs';
      await AuthService.logout();
      _user = null;
      return;
    }

    _user = candidate;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
