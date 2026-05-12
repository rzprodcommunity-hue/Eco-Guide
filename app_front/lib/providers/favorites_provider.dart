import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trail.dart';

class FavoritesProvider extends ChangeNotifier {
  static const _key = 'favorite_trails';

  final List<Trail> _favorites = [];

  List<Trail> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(String trailId) =>
      _favorites.any((t) => t.id == trailId);

  FavoritesProvider() {
    _load();
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
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _favorites.addAll(
        list.map((e) => Trail.fromJson(e as Map<String, dynamic>)),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_favorites.map((t) => t.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
