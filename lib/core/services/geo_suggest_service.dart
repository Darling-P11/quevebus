import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeoSuggestion {
  final String label;
  final double lat;
  final double lon;

  GeoSuggestion({required this.label, required this.lat, required this.lon});
}

class GeoSuggestService {
  /// Nominatim OSM: sugerencias solo Ecuador, sesgadas por lat/lon del usuario.
  /// Nota: Para producción, configura tu propio host/caching y respeta la política de uso.
  static Future<List<GeoSuggestion>> suggest({
    required String query,
    LatLng? bias,
    int limit = 8,
  }) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?format=jsonv2'
      '&countrycodes=ec'
      '&addressdetails=1'
      '&limit=$limit'
      '${bias != null ? '&lat=${bias.latitude}&lon=${bias.longitude}' : ''}'
      '&q=${Uri.encodeQueryComponent(query)}',
    );

    final res = await http.get(
      uri,
      headers: {
        'User-Agent': 'QueveBus/0.1 (edu prototype; contact: app@example.com)',
      },
    );
    if (res.statusCode != 200) return [];

    final List data = jsonDecode(res.body) as List;
    return data
        .map((e) {
          final display = (e['display_name'] as String?) ?? 'Ubicación';
          final lat = double.tryParse(e['lat']?.toString() ?? '') ?? 0;
          final lon = double.tryParse(e['lon']?.toString() ?? '') ?? 0;
          return GeoSuggestion(label: display, lat: lat, lon: lon);
        })
        .where((s) => s.lat != 0 && s.lon != 0)
        .toList();
  }
}
