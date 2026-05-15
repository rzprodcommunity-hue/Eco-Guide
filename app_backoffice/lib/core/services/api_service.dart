import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static String? _token;

  static SupabaseClient get _supabase => Supabase.instance.client;

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static String? get token =>
      _token ?? _supabase.auth.currentSession?.accessToken;

  static Map<String, String> get headers {
    final currentToken = token;
    return {
      'Content-Type': 'application/json',
      if (currentToken != null) 'Authorization': 'Bearer $currentToken',
    };
  }

  static Future<dynamic> get(
    String url, {
    Map<String, String>? queryParams,
  }) async {
    final path = _path(url);

    if (path == '/admin/dashboard') {
      final results = await Future.wait([
        _supabase.from('profiles').select('id'),
        _supabase.from('trails').select('id'),
        _supabase.from('pois').select('id'),
        _supabase.from('quizzes').select('id'),
        _supabase.from('local_services').select('id'),
        _supabase.from('sos_alerts').select('id').eq('status', 'active'),
      ]);
      return {
        'summary': {
          'users': (results[0] as List).length,
          'trails': (results[1] as List).length,
          'pois': (results[2] as List).length,
          'quizzes': (results[3] as List).length,
          'localServices': (results[4] as List).length,
          'activities': 0,
          'activeSosAlerts': (results[5] as List).length,
        },
        'recentActivities': [],
      };
    }

    if (path == '/users') {
      return _list('profiles', queryParams ?? {});
    }
    if (path.startsWith('/users/')) {
      return _single('profiles', path.split('/').last);
    }

    if (path == '/trails') return _list('trails', queryParams ?? {});
    if (path.startsWith('/trails/'))
      return _single('trails', path.split('/').last);

    if (path == '/pois') return _list('pois', queryParams ?? {});
    if (path.startsWith('/pois/')) return _single('pois', path.split('/').last);

    if (path == '/quizzes') return _list('quizzes', queryParams ?? {});
    if (path.startsWith('/quizzes/')) {
      return _single('quizzes', path.split('/').last);
    }

    if (path == '/local-services') {
      return _list('local_services', queryParams ?? {});
    }
    if (path.startsWith('/local-services/')) {
      return _single('local_services', path.split('/').last);
    }

    if (path == '/sos/alerts/active') {
      return _supabase
          .from('sos_alerts')
          .select()
          .eq('status', 'active')
          .order('createdAt', ascending: false);
    }
    if (path == '/sos/alerts') {
      return _supabase
          .from('sos_alerts')
          .select()
          .order('createdAt', ascending: false);
    }

    throw ApiException('Endpoint Supabase non supporte: $path', 404);
  }

  static Future<dynamic> post(String url, {dynamic body}) async {
    final table = _tableForPath(_path(url));
    final payload = _cleanPayload(body);
    return _supabase.from(table).insert(payload).select().single();
  }

  static Future<dynamic> patch(String url, {dynamic body}) async {
    final path = _path(url);

    if (path.startsWith('/sos/alerts/') && path.endsWith('/resolve')) {
      final id = path.split('/')[3];
      return _supabase.rpc('resolve_sos_alert', params: {'alert_id': id});
    }

    final segments = path.split('/').where((part) => part.isNotEmpty).toList();
    if (segments.length < 2) {
      throw ApiException('URL de mise a jour invalide: $path', 400);
    }

    final table = _tableForCollection(segments.first);
    final id = segments.last;
    return _supabase
        .from(table)
        .update(_cleanPayload(body))
        .eq('id', id)
        .select()
        .single();
  }

  static Future<dynamic> delete(String url) async {
    final path = _path(url);
    final segments = path.split('/').where((part) => part.isNotEmpty).toList();
    if (segments.length < 2) {
      throw ApiException('URL de suppression invalide: $path', 400);
    }

    final table = _tableForCollection(segments.first);
    final id = segments.last;
    await _supabase.from(table).delete().eq('id', id);
    return null;
  }

  static Future<Map<String, dynamic>> _list(
    String table,
    Map<String, String> params,
  ) async {
    final page = int.tryParse(params['page'] ?? '') ?? 1;
    final limit = int.tryParse(params['limit'] ?? '') ?? 10;
    final from = (page - 1) * limit;
    final to = from + limit - 1;

    dynamic query = _supabase.from(table).select();

    if (params['difficulty'] != null)
      query = query.eq('difficulty', params['difficulty']!);
    if (params['region'] != null)
      query = query.ilike('region', '%${params['region']}%');
    if (params['type'] != null) query = query.eq('type', params['type']!);
    if (params['trailId'] != null)
      query = query.eq('trailId', params['trailId']!);
    if (params['category'] != null)
      query = query.eq('category', params['category']!);
    if (params['minDistance'] != null) {
      query = query.gte('distance', double.parse(params['minDistance']!));
    }
    if (params['maxDistance'] != null) {
      query = query.lte('distance', double.parse(params['maxDistance']!));
    }
    if (params['maxDuration'] != null) {
      query = query.lte('estimatedDuration', int.parse(params['maxDuration']!));
    }

    final rows = await query
        .order('createdAt', ascending: false)
        .range(from, to);

    return {
      'data': rows,
      'meta': {
        'total': rows.length,
        'page': page,
        'limit': limit,
        'totalPages': rows.isEmpty ? 0 : 1,
      },
    };
  }

  static Future<dynamic> _single(String table, String id) {
    return _supabase.from(table).select().eq('id', id).single();
  }

  static Map<String, dynamic> _cleanPayload(dynamic body) {
    final payload = Map<String, dynamic>.from(body as Map? ?? const {});
    payload.removeWhere((_, value) => value == null);
    return payload;
  }

  static String _path(String url) {
    final parsed = Uri.parse(url);
    final path = parsed.path;
    final apiIndex = path.indexOf('/api');
    return apiIndex >= 0 ? path.substring(apiIndex + 4) : path;
  }

  static String _tableForPath(String path) {
    final collection = path.split('/').where((part) => part.isNotEmpty).first;
    return _tableForCollection(collection);
  }

  static String _tableForCollection(String collection) {
    return switch (collection) {
      'users' => 'profiles',
      'trails' => 'trails',
      'pois' => 'pois',
      'quizzes' => 'quizzes',
      'local-services' => 'local_services',
      _ => throw ApiException('Collection Supabase inconnue: $collection', 404),
    };
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
