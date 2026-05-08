import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  late final AuthService _authService;

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._apiClient) {
    _authService = AuthService(_apiClient);
    _loadStoredAuth();
  }

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isDemoUser => _token == 'demo-token';

  Future<void> _loadStoredAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(AppConstants.tokenKey);
      final storedUserJson = prefs.getString(AppConstants.userKey);

      if (storedToken != null && storedUserJson != null) {
        _token = storedToken;
        _user = User.fromJson(jsonDecode(storedUserJson) as Map<String, dynamic>);
        _apiClient.setToken(_token);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.login(email: email, password: password);
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

  Future<void> loginAsStaticUser() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final demoUser = User(
        id: 'demo-user',
        email: 'demo@ecoguide.local',
        role: 'user',
        firstName: 'Demo',
        lastName: 'User',
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _saveAuth('demo-token', demoUser);
    } catch (e) {
      _error = e.toString();
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
    _token = null;
    _user = null;
    _apiClient.setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);

    notifyListeners();
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
}
