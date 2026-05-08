import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/sos_service.dart';

class OfflineSosService {
  static const String _queueKey = 'offline_sos_queue';

  static Future<void> saveOfflineAlert(double latitude, double longitude, String message) async {
    final prefs = await SharedPreferences.getInstance();
    final queueStr = prefs.getString(_queueKey) ?? '[]';
    final List<dynamic> queue = json.decode(queueStr);

    queue.add({
      'latitude': latitude,
      'longitude': longitude,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_queueKey, json.encode(queue));
    print('🚨 SOS Alert queued offline. Total queued: ${queue.length}');
  }

  static Future<void> syncOfflineAlerts(SosService sosService) async {
    final prefs = await SharedPreferences.getInstance();
    final queueStr = prefs.getString(_queueKey);
    
    if (queueStr == null) return;
    
    final List<dynamic> queue = json.decode(queueStr);
    if (queue.isEmpty) return;

    print('📡 Attempting to sync ${queue.length} offline SOS alerts...');
    
    List<dynamic> failedQueue = [];

    for (var alert in queue) {
      try {
        await sosService.sendAlert(
          latitude: alert['latitude'],
          longitude: alert['longitude'],
          message: '${alert['message']} (Envoi differe suite a une perte de reseau. Initie le ${alert['timestamp']})',
        );
        print('✅ Offline SOS Alert synced successfully.');
      } catch (e) {
        print('❌ Failed to sync Offline SOS Alert: $e');
        failedQueue.add(alert);
      }
    }

    // Update queue with only the ones that still failed
    await prefs.setString(_queueKey, json.encode(failedQueue));
  }
}
