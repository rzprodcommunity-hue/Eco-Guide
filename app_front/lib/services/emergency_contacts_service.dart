import 'package:supabase_flutter/supabase_flutter.dart';

/// Service responsible for fetching emergency contacts managed from the
/// backoffice (stored in the Supabase `emergency_contacts` table).
class EmergencyContactsService {
  /// Returns the list of active emergency contacts ordered by creation date.
  ///
  /// Each row contains at least: `name`, `subtitle`, `phone`.
  /// Returns an empty list on any error (e.g. offline) so callers can
  /// fall back to hardcoded contacts.
  static Future<List<Map<String, dynamic>>> fetchActive() async {
    try {
      final response = await Supabase.instance.client
          .from('emergency_contacts')
          .select()
          .eq('isActive', true)
          .order('createdAt');

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }
}
