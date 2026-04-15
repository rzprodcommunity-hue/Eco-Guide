import '../core/constants/api_constants.dart';
import '../models/trail.dart';
import 'api_client.dart';

class TrailService {
  final ApiClient _client;

  TrailService(this._client);

  Future<PaginatedResponse<Trail>> getTrails({
    int page = 1,
    int limit = 10,
    String? difficulty,
    String? region,
    String? search,
    double? minDistance,
    double? maxDistance,
    int? maxDuration,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (difficulty != null) 'difficulty': difficulty,
      if (region != null) 'region': region,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (minDistance != null) 'minDistance': minDistance.toString(),
      if (maxDistance != null) 'maxDistance': maxDistance.toString(),
      if (maxDuration != null) 'maxDuration': maxDuration.toString(),
    };

    final response = await _client.get(ApiConstants.trails, queryParams: queryParams);
    return PaginatedResponse.fromJson(
      response,
      (json) => Trail.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<Trail>> getNearbyTrails({
    required double lat,
    required double lng,
    double radius = 50,
  }) async {
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radius.toString(),
    };

    final response = await _client.get(ApiConstants.trailsNearby, queryParams: queryParams);
    final data = response['data'] as List? ?? response as List;
    return data.map((json) => Trail.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Trail> getTrailById(String id) async {
    final response = await _client.get('${ApiConstants.trails}/$id');
    return Trail.fromJson(response);
  }

  Future<List<Trail>> getAllTrails({
    int pageSize = 100,
    String? difficulty,
    String? region,
    String? search,
    double? minDistance,
    double? maxDistance,
    int? maxDuration,
  }) async {
    final all = <Trail>[];
    var page = 1;
    var totalPages = 1;

    do {
      final response = await getTrails(
        page: page,
        limit: pageSize,
        difficulty: difficulty,
        region: region,
        search: search,
        minDistance: minDistance,
        maxDistance: maxDistance,
        maxDuration: maxDuration,
      );

      all.addAll(response.data);
      totalPages = response.totalPages > 0 ? response.totalPages : 1;
      page++;
    } while (page <= totalPages);

    return all;
  }
}

class PaginatedResponse<T> {
  final List<T> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  PaginatedResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final dataList = json['data'] as List? ?? [];

    return PaginatedResponse(
      data: dataList.map(fromJsonT).toList(),
      total: meta['total'] as int? ?? dataList.length,
      page: meta['page'] as int? ?? 1,
      limit: meta['limit'] as int? ?? 10,
      totalPages: meta['totalPages'] as int? ?? 1,
    );
  }
}
