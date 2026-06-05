import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trail.dart';

/// Stores favorite trails PER ACCOUNT. The persistence key is namespaced by the
/// current user id, so signing into a different account never shows another
/// user's favorites. Call [setUser] whenever the authenticated user changes.
class FavoritesProvider extends ChangeNotifier {
  static const _legacyKey = 'favorite_trails';

  final List<Trail> _favorites = [];
  String? _userId;

  List<Trail> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(String trailId) => _favorites.any((t) => t.id == trailId);

  String get _key => 'favorite_trails_${_userId ?? 'guest'}';

  FavoritesProvider() {
    _load();
  }

  /// Switch the active account. Reloads that account's favorites (and clears the
  /// in-memory list first so a logout/login never leaks the previous user's).
  Future<void> setUser(String? userId) async {
    if (_userId == userId) return;
    _userId = userId;
    _favorites.clear();
    notifyListeners();
    await _load();
  }

  Future<void> toggle(Trail trail) async {
    if (isFavorite(trail.id)) {
      _favorites.removeWhere((t) => t.id == trail.id);
    } else {
      _favorites.add(trail);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // One-time migration: an older build stored favorites under a single global
    // key shared by every account. Drop it so it can never leak across users.
    if (prefs.containsKey(_legacyKey)) {
      await prefs.remove(_legacyKey);
    }

    final raw = prefs.getString(_key);
    _favorites.clear();
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _favorites.addAll(
          list.map((e) => Trail.fromJson(e as Map<String, dynamic>)),
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_favorites.map((t) => t.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
