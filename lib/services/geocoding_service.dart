import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SearchResult {
  const SearchResult({required this.title, required this.subtitle, required this.position});

  final String title;
  final String subtitle;
  final LatLng position;
}

/// Turns a place name, address or "lat, lng" text into coordinates.
///
/// Uses Google Places when built with `--dart-define=PLACES_API_KEY=...`, otherwise
/// OpenStreetMap's Nominatim.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  static const _placesApiKey = String.fromEnvironment('PLACES_API_KEY');
  static const _userAgent = 'FakeLocation/1.0 (personal use)';

  final http.Client _client;

  bool get usesGoogle => _placesApiKey.isNotEmpty;

  /// Results near [near] are preferred but not required.
  Future<List<SearchResult>> search(String query, {LatLng? near}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final coordinates = parseCoordinates(q);
    if (coordinates != null) {
      return [SearchResult(title: 'Coordinates', subtitle: q, position: coordinates)];
    }
    return usesGoogle ? _searchGoogle(q, near) : _searchNominatim(q, near);
  }

  /// Parses "28.61, 77.20" style input; null if it is not a coordinate pair.
  static LatLng? parseCoordinates(String text) {
    final match = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)\s*$').firstMatch(text);
    if (match == null) return null;
    final lat = double.parse(match.group(1)!);
    final lng = double.parse(match.group(2)!);
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return LatLng(lat, lng);
  }

  Future<List<SearchResult>> _searchNominatim(String q, LatLng? near) async {
    final params = {
      'q': q,
      'format': 'jsonv2',
      'limit': '8',
      'addressdetails': '0',
      if (near != null)
        // Roughly a 50 km box around [near], used as a preference only.
        'viewbox': '${near.longitude - 0.5},${near.latitude + 0.5},${near.longitude + 0.5},${near.latitude - 0.5}',
    };
    final response = await _client.get(
      Uri.https('nominatim.openstreetmap.org', '/search', params),
      headers: {'User-Agent': _userAgent, 'Accept-Language': 'en'},
    );
    if (response.statusCode != 200) {
      throw GeocodingException('Search failed (${response.statusCode})');
    }
    return (jsonDecode(response.body) as List).map((e) {
      final m = e as Map<String, dynamic>;
      final display = m['display_name'] as String? ?? '';
      final name = (m['name'] as String?)?.trim();
      final title = (name == null || name.isEmpty) ? display.split(',').first : name;
      return SearchResult(
        title: title,
        subtitle: display,
        position: LatLng(double.parse(m['lat'] as String), double.parse(m['lon'] as String)),
      );
    }).toList();
  }

  Future<List<SearchResult>> _searchGoogle(String q, LatLng? near) async {
    final body = {
      'textQuery': q,
      'pageSize': 8,
      if (near != null)
        'locationBias': {
          'circle': {
            'center': {'latitude': near.latitude, 'longitude': near.longitude},
            'radius': 50000.0,
          },
        },
    };
    final response = await _client.post(
      Uri.https('places.googleapis.com', '/v1/places:searchText'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _placesApiKey,
        'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,places.location',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw GeocodingException('Search failed (${response.statusCode})');
    }
    final places = (jsonDecode(response.body) as Map<String, dynamic>)['places'] as List? ?? [];
    return places.map((e) {
      final m = e as Map<String, dynamic>;
      final location = m['location'] as Map<String, dynamic>;
      return SearchResult(
        title: (m['displayName'] as Map<String, dynamic>?)?['text'] as String? ?? '',
        subtitle: m['formattedAddress'] as String? ?? '',
        position: LatLng(
          (location['latitude'] as num).toDouble(),
          (location['longitude'] as num).toDouble(),
        ),
      );
    }).toList();
  }
}

class GeocodingException implements Exception {
  GeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}
