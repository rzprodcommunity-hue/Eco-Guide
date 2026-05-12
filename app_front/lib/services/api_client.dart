import 'package:supabase_flutter/supabase_flutter.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException: $statusCode - $message';
}

class ApiClient {
  SupabaseClient get _supabase => Supabase.instance.client;

  void setToken(String? token) {
    // Supabase Flutter persists and refreshes its own auth session.
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      if (endpoint == '/trails') return _getTrails(queryParams ?? {});
      if (endpoint == '/trails/nearby')
        return _rpcList('nearby_trails', {
          'lat': _double(queryParams, 'lat'),
          'lng': _double(queryParams, 'lng'),
          'radius': _double(queryParams, 'radius', fallback: 50),
        });
      if (endpoint.startsWith('/trails/')) {
        return _singleById('trails', endpoint.split('/').last);
      }

      if (endpoint == '/pois') return _getPois(queryParams ?? {});
      if (endpoint == '/pois/nearby')
        return _rpcList('nearby_pois', {
          'lat': _double(queryParams, 'lat'),
          'lng': _double(queryParams, 'lng'),
          'radius': _double(queryParams, 'radius', fallback: 10),
          'poi_type': queryParams?['type'],
        });
      if (endpoint.startsWith('/pois/trail/')) {
        final trailId = endpoint.split('/').last;
        final rows = await _supabase
            .from('pois')
            .select()
            .eq('trailId', trailId)
            .eq('isActive', true)
            .order('createdAt', ascending: true);
        return {'data': rows};
      }
      if (endpoint.startsWith('/pois/')) {
        return _singleById('pois', endpoint.split('/').last);
      }

      if (endpoint == '/local-services') {
        return _getLocalServices(queryParams ?? {});
      }
      if (endpoint == '/local-services/nearby') {
        return _rpcList('nearby_local_services', {
          'lat': _double(queryParams, 'lat'),
          'lng': _double(queryParams, 'lng'),
          'radius': _double(queryParams, 'radius', fallback: 50),
          'service_category': queryParams?['category'],
        });
      }
      if (endpoint.startsWith('/local-services/')) {
        return _singleById('local_services', endpoint.split('/').last);
      }

      if (endpoint == '/quizzes') return _getQuizzes(queryParams ?? {});
      if (endpoint == '/quizzes/random') {
        return _getRandomQuizzes(queryParams ?? {});
      }
      if (endpoint == '/quizzes/categories') {
        return _rpcList('quiz_category_stats', {});
      }
      if (endpoint.startsWith('/quizzes/category/')) {
        final category = endpoint.split('/').last;
        final rows = await _supabase
            .from('quizzes')
            .select()
            .eq('category', category)
            .eq('isActive', true)
            .order('createdAt', ascending: false);
        return {'data': rows};
      }
      if (endpoint.startsWith('/quizzes/trail/')) {
        final trailId = endpoint.split('/').last;
        final rows = await _supabase
            .from('quizzes')
            .select()
            .eq('trailId', trailId)
            .eq('isActive', true);
        return {'data': rows};
      }
      if (endpoint == '/quizzes/scores/me') {
        final rows = await _supabase
            .from('quiz_scores')
            .select()
            .eq('userId', _requiredUserId())
            .order('totalScore', ascending: false);
        return {'data': rows};
      }
      if (endpoint == '/quizzes/scores/me/summary') {
        return await _supabase.rpc('user_quiz_summary') as Map<String, dynamic>;
      }
      if (endpoint.startsWith('/quizzes/scores/leaderboard')) {
        return _getLeaderboard(queryParams ?? {});
      }
      if (endpoint.startsWith('/quizzes/')) {
        return _singleById('quizzes', endpoint.split('/').last);
      }

      if (endpoint == '/activities/me') {
        return _getMyActivities(queryParams ?? {});
      }
      if (endpoint == '/activities/me/stats') {
        return await _supabase.rpc('user_activity_stats')
            as Map<String, dynamic>;
      }
      if (endpoint == '/activities/me/recent') {
        final limit = _int(queryParams, 'limit', fallback: 10);
        final rows = await _supabase
            .from('activities')
            .select()
            .eq('userId', _requiredUserId())
            .order('createdAt', ascending: false)
            .limit(limit);
        return {'data': rows};
      }

      if (endpoint == '/offline/packages') {
        return await _supabase.rpc('offline_packages') as Map<String, dynamic>;
      }

      throw ApiException(404, 'Unsupported Supabase endpoint: $endpoint');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(500, e.toString());
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final payload = body ?? {};

      if (endpoint == '/activities') {
        final inserted = await _supabase
            .from('activities')
            .insert({...payload, 'userId': _requiredUserId()})
            .select()
            .single();
        return inserted;
      }

      if (endpoint == '/sos/alert') {
        final inserted = await _supabase.rpc(
          'create_sos_alert',
          params: {
            'latitude': payload['latitude'],
            'longitude': payload['longitude'],
            'message': payload['message'],
            'emergency_contact': payload['emergencyContact'],
          },
        );
        return inserted as Map<String, dynamic>;
      }

      if (endpoint == '/quizzes/scores') {
        final score = await _supabase.rpc(
          'submit_quiz_score',
          params: {
            'category': payload['category'],
            'score': payload['score'],
            'correct_answers': payload['correctAnswers'],
            'total_questions': payload['totalQuestions'],
          },
        );
        return score as Map<String, dynamic>;
      }

      if (endpoint == '/offline/download') {
        final inserted = await _supabase
            .from('offline_cache')
            .insert({...payload, 'userId': _requiredUserId()})
            .select()
            .single();
        return inserted;
      }

      throw ApiException(404, 'Unsupported Supabase POST endpoint: $endpoint');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(500, e.toString());
    }
  }

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    throw ApiException(404, 'Unsupported Supabase PATCH endpoint: $endpoint');
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    if (endpoint.startsWith('/offline/download/')) {
      await _supabase
          .from('offline_cache')
          .delete()
          .eq('id', endpoint.split('/').last)
          .eq('userId', _requiredUserId());
      return {};
    }
    throw ApiException(404, 'Unsupported Supabase DELETE endpoint: $endpoint');
  }

  Future<Map<String, dynamic>> _getTrails(Map<String, String> params) async {
    final page = _int(params, 'page', fallback: 1);
    final limit = _int(params, 'limit', fallback: 10);
    final from = (page - 1) * limit;
    final to = from + limit - 1;
    dynamic query = _supabase.from('trails').select().eq('isActive', true);

    if (params['difficulty'] != null) {
      query = query.eq('difficulty', params['difficulty']!);
    }
    if (params['region'] != null) {
      query = query.ilike('region', '%${params['region']}%');
    }
    if (params['search'] != null) {
      final search = '${params['search']}%';
      query = query.or(
        'name.ilike.$search,region.ilike.$search,description.ilike.$search',
      );
    }
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
    return _paginated(rows as List<dynamic>, page, limit);
  }

  Future<Map<String, dynamic>> _getPois(Map<String, String> params) async {
    final page = _int(params, 'page', fallback: 1);
    final limit = _int(params, 'limit', fallback: 10);
    final from = (page - 1) * limit;
    final to = from + limit - 1;
    dynamic query = _supabase.from('pois').select().eq('isActive', true);

    if (params['type'] != null) query = query.eq('type', params['type']!);
    if (params['trailId'] != null)
      query = query.eq('trailId', params['trailId']!);
    if (params['search'] != null) {
      final search = '${params['search']}%';
      query = query.or(
        'name.ilike.$search,description.ilike.$search,badge.ilike.$search',
      );
    }

    final rows = await query
        .order('createdAt', ascending: false)
        .range(from, to);
    return _paginated(rows as List<dynamic>, page, limit);
  }

  Future<Map<String, dynamic>> _getLocalServices(
    Map<String, String> params,
  ) async {
    final page = _int(params, 'page', fallback: 1);
    final limit = _int(params, 'limit', fallback: 10);
    final from = (page - 1) * limit;
    final to = from + limit - 1;
    dynamic query = _supabase
        .from('local_services')
        .select()
        .eq('isActive', true)
        .eq('isVerified', true);

    if (params['category'] != null)
      query = query.eq('category', params['category']!);
    if (params['search'] != null) {
      final search = '${params['search']}%';
      query = query.or(
        'name.ilike.$search,description.ilike.$search,address.ilike.$search',
      );
    }

    final rows = await query
        .order('createdAt', ascending: false)
        .range(from, to);
    return _paginated(rows as List<dynamic>, page, limit);
  }

  Future<Map<String, dynamic>> _getQuizzes(Map<String, String> params) async {
    final page = _int(params, 'page', fallback: 1);
    final limit = _int(params, 'limit', fallback: 10);
    final from = (page - 1) * limit;
    final to = from + limit - 1;
    final rows = await _supabase
        .from('quizzes')
        .select()
        .eq('isActive', true)
        .order('createdAt', ascending: false)
        .range(from, to);
    return _paginated(rows, page, limit);
  }

  Future<Map<String, dynamic>> _getRandomQuizzes(
    Map<String, String> params,
  ) async {
    final count = _int(params, 'count', fallback: 5);
    dynamic query = _supabase.from('quizzes').select().eq('isActive', true);
    if (params['category'] != null)
      query = query.eq('category', params['category']!);
    final rows = await query.limit(count);
    final shuffled = List<dynamic>.from(rows as List)..shuffle();
    return {'data': shuffled.take(count).toList()};
  }

  Future<Map<String, dynamic>> _getLeaderboard(
    Map<String, String> params,
  ) async {
    final limit = _int(params, 'limit', fallback: 10);
    dynamic query = _supabase.from('quiz_scores').select();
    if (params['category'] != null)
      query = query.eq('category', params['category']!);
    final rows = await query.order('totalScore', ascending: false).limit(limit);
    return {'data': rows};
  }

  Future<Map<String, dynamic>> _getMyActivities(
    Map<String, String> params,
  ) async {
    final page = _int(params, 'page', fallback: 1);
    final limit = _int(params, 'limit', fallback: 10);
    final from = (page - 1) * limit;
    final to = from + limit - 1;
    final rows = await _supabase
        .from('activities')
        .select()
        .eq('userId', _requiredUserId())
        .order('createdAt', ascending: false)
        .range(from, to);
    return _paginated(rows, page, limit);
  }

  Future<Map<String, dynamic>> _singleById(String table, String id) async {
    final row = await _supabase.from(table).select().eq('id', id).single();
    return row;
  }

  Future<Map<String, dynamic>> _rpcList(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final cleanParams = Map<String, dynamic>.from(params)
      ..removeWhere((_, value) => value == null);
    final rows = await _supabase.rpc(functionName, params: cleanParams);
    return {'data': rows as List<dynamic>};
  }

  Map<String, dynamic> _paginated(List<dynamic> rows, int page, int limit) {
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

  String _requiredUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw ApiException(401, 'Authentication required');
    return userId;
  }

  int _int(Map<String, String>? params, String key, {required int fallback}) {
    return int.tryParse(params?[key] ?? '') ?? fallback;
  }

  double _double(
    Map<String, String>? params,
    String key, {
    double fallback = 0,
  }) {
    return double.tryParse(params?[key] ?? '') ?? fallback;
  }

  void dispose() {}
}
