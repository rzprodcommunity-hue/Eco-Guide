import 'package:supabase_flutter/supabase_flutter.dart';

class SocketService {
  static final Map<String, RealtimeChannel> _channels = {};

  static void init() {
    // Channels are lazily created in on() because each legacy event maps to a
    // different Supabase table.
  }

  static void on(String event, Function(dynamic) callback) {
    if (_channels.containsKey(event)) return;

    final table = switch (event) {
      'trail_updated' => 'trails',
      'poi_updated' => 'pois',
      'service_updated' => 'local_services',
      'quiz_updated' => 'quizzes',
      'sos_alert_created' => 'sos_alerts',
      'sos_alert_resolved' => 'sos_alerts',
      _ => null,
    };

    if (table == null) return;

    final channel = Supabase.instance.client.channel('public:$table:$event')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (payload) {
          callback({
            'action': payload.eventType.name,
            'data': payload.newRecord,
            'old': payload.oldRecord,
          });
        },
      ).subscribe();

    _channels[event] = channel;
  }

  static void off(String event) {
    final channel = _channels.remove(event);
    if (channel == null) return;
    Supabase.instance.client.removeChannel(channel);
  }
}
