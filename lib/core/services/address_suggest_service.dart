import 'dart:convert';
import 'package:http/http.dart' as http;

/// Modelo simple para la sugerencia de dirección
class AddressSuggestion {
  final String label; // título visible
  final String secondary; // línea secundaria (barrio/ciudad)
  final double lat;
  final double lon;

  AddressSuggestion({
    required this.label,
    required this.secondary,
    required this.lat,
    required this.lon,
  });
}

/// Servicio contra Nominatim (OpenStreetMap) restringido a Ecuador.
/// - Prioriza resultados cerca de (lat, lon) si se proveen.
/// - Devuelve como máximo 8 sugerencias.
class AddressSuggestService {
  static const _base = 'https://nominatim.openstreetmap.org/search';
  static const _max = 8;

  // IMPORTANTE: Nominatim exige un User-Agent identificable.
  final Map<String, String> _headers = const {
    'User-Agent': 'QueveBus/0.1 (contacto: dev@quevebus.app)',
    'Accept': 'application/json',
  };

  Future<List<AddressSuggestion>> search(
    String query, {
    double? lat,
    double? lon,
  }) async {
    if (query.trim().isEmpty) return const [];

    // Parámetros base
    final params = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'countrycodes': 'ec', // ← SOLO Ecuador
      'limit': '$_max',
      // 'dedupe': '1',               // opcional
      // 'namedetails': '1',          // opcional
    };

    // Si tenemos ubicación actual, pasamos un "viewbox" pequeño para
    // favorecer cercanía sin bloquear otros resultados.
    if (lat != null && lon != null) {
      const d = 0.2; // ~22 km aprox
      final left = lon - d;
      final right = lon + d;
      final top = lat + d;
      final bottom = lat - d;
      params['viewbox'] = '$left,$top,$right,$bottom';
      // bounded=0 para no excluir fuera del viewbox, solo priorizar
      params['bounded'] = '0';
    }

    final uri = Uri.parse(_base).replace(queryParameters: params);

    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode != 200) return const [];

    final List data = json.decode(resp.body) as List;

    return data.map((raw) {
      final lat = double.tryParse(raw['lat']?.toString() ?? '') ?? 0.0;
      final lon = double.tryParse(raw['lon']?.toString() ?? '') ?? 0.0;

      // Etiquetas amigables
      final address = (raw['address'] ?? {}) as Map<String, dynamic>;
      final name = (raw['name'] ?? '').toString().trim();
      final road = (address['road'] ?? address['pedestrian'] ?? '').toString();
      final house = (address['house_number'] ?? '').toString();
      final suburb = (address['suburb'] ?? address['neighbourhood'] ?? '')
          .toString();
      final city =
          (address['city'] ?? address['town'] ?? address['village'] ?? '')
              .toString();

      final primary = [
        if (name.isNotEmpty) name else null,
        if (house.isNotEmpty || road.isNotEmpty)
          [road, house]
              .where((e) => e != null && e.toString().trim().isNotEmpty)
              .join(' ')
              .trim(),
      ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' • ');

      final secondary = [
        suburb,
        city,
      ].where((e) => e.toString().trim().isNotEmpty).join(', ');

      return AddressSuggestion(
        label: primary.isEmpty
            ? (raw['display_name'] ?? '').toString()
            : primary,
        secondary: secondary,
        lat: lat,
        lon: lon,
      );
    }).toList();
  }
}
