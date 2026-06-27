import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place.dart';

/// City search via the Open-Meteo Geocoding API (no key).
class GeocodingService {
  static const _base = 'https://geocoding-api.open-meteo.com/v1/search';

  final http.Client _client;
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  /// Returns up to 5 matching places. Empty list means "no cities found".
  Future<List<Place>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final uri = Uri.parse(_base).replace(queryParameters: {
      'name': trimmed,
      'count': '5',
      'language': 'en',
      'format': 'json',
    });

    final res = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Search failed (${res.statusCode})');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = json['results'];
    if (results is! List) return []; // missing key => no matches

    return results
        .whereType<Map<String, dynamic>>()
        .map(Place.fromGeocoding)
        .toList();
  }
}
