import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model for an emergency contact (table `emergency_contacts`).
/// These contacts are surfaced in the app_front SOS page.
class EmergencyContact {
  final String id;
  final String name;
  final String? subtitle;
  final String? phone;
  final bool isActive;

  EmergencyContact({
    required this.id,
    required this.name,
    this.subtitle,
    this.phone,
    required this.isActive,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      subtitle: map['subtitle']?.toString(),
      phone: map['phone']?.toString(),
      isActive: map['isActive'] == null ? true : map['isActive'] == true,
    );
  }
}

/// Provider handling full CRUD of the `emergency_contacts` table directly
/// through Supabase.
class EmergencyContactsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  List<EmergencyContact> _contacts = [];
  bool _isLoading = false;
  String? _error;

  List<EmergencyContact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Loads all emergency contacts ordered by creation date.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _client
          .from('emergency_contacts')
          .select()
          .order('createdAt');
      _contacts = (data as List)
          .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Inserts a new contact then reloads the list.
  Future<bool> create(Map<String, dynamic> payload) async {
    try {
      await _client.from('emergency_contacts').insert(payload);
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Updates an existing contact then reloads the list.
  Future<bool> update(String id, Map<String, dynamic> payload) async {
    try {
      await _client.from('emergency_contacts').update(payload).eq('id', id);
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Deletes a contact then reloads the list.
  Future<bool> remove(String id) async {
    try {
      await _client.from('emergency_contacts').delete().eq('id', id);
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
