// lib/core/services/street_router.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Servicio muy simple para rutear una secuencia de puntos por calles.
/// Usa OSRM demo: https://router.project-osrm.org (solo para pruebas).
/// Producción: monta tu propio OSRM/Valhalla o un proveedor con SLA.
///
/// NOTA: OSRM demo tiene límites. Este servicio:
///  - Divide la secuencia en "chunks" para no exceder la URL
///  - Une los tramos en una sola polilínea
class StreetRouter {
  StreetRouter._();
  static final StreetRouter instance = StreetRouter._();

  // Cache en memoria para evitar pedir lo mismo varias veces
  final Map<String, List<LatLng>> _cache = {};

  /// Rutear toda la secuencia [stops] siguiendo calles.
  /// Devuelve la polilínea resultante (vacía si falla).
  Future<List<LatLng>> routeByStreets(List<LatLng> stops) async {
    if (stops.length < 2) return stops;

    // OSRM acepta bastantes coords, pero hacemos chunks razonables (p.ej. 25)
    const chunkSize = 25;
    final chunks = <List<LatLng>>[];
    for (int i = 0; i < stops.length; i += (chunkSize - 1)) {
      final end = (i + chunkSize < stops.length) ? i + chunkSize : stops.length;
      // Importante: solapar 1 punto para que el final del chunk A sea el inicio del chunk B
      final sub = stops.sublist(i, end);
      if (i != 0 && sub.isNotEmpty) {
        sub.insert(0, stops[i]); // solape
      }
      chunks.add(sub);
    }

    final result = <LatLng>[];
    for (int idx = 0; idx < chunks.length; idx++) {
      final piece = await _routeChunk(chunks[idx]);
      if (piece.isEmpty) {
        // si falla un pedazo, devolvemos lo que tengamos + recta del resto
        // (fallback simple)
        result.addAll(chunks[idx]);
      } else {
        if (idx > 0 && result.isNotEmpty && piece.isNotEmpty) {
          // evita duplicar el punto de unión
          if (_equalsLatLng(result.last, piece.first)) {
            result.addAll(piece.skip(1));
          } else {
            result.addAll(piece);
          }
        } else {
          result.addAll(piece);
        }
      }
    }
    return result;
  }

  Future<List<LatLng>> _routeChunk(List<LatLng> pts) async {
    if (pts.length < 2) return pts;

    final coordsStr = pts.map((p) => '${p.longitude},${p.latitude}').join(';');

    // cache key
    final key = 'osrm:$coordsStr';
    final cached = _cache[key];
    if (cached != null) return cached;

    final url =
        'https://router.project-osrm.org/route/v1/driving/$coordsStr'
        '?overview=full&geometries=geojson&steps=false&continue_straight=true';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return <LatLng>[];

      final data = json.decode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return <LatLng>[];

      final geom = routes.first['geometry'];
      // geometries=geojson ⇒ geometry.coordinates = [[lon,lat], ...]
      final coords = (geom['coordinates'] as List)
          .map<LatLng>(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList();

      _cache[key] = coords;
      return coords;
    } catch (_) {
      return <LatLng>[];
    }
  }

  bool _equalsLatLng(LatLng a, LatLng b, {double eps = 1e-6}) {
    return ((a.latitude - b.latitude).abs() < eps &&
        (a.longitude - b.longitude).abs() < eps);
  }
}
