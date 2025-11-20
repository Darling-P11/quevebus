import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// Punto de una línea, con el "Point" del CSV y su coordenada.
class BusLinePoint {
  final int point; // valor de la columna Point en el CSV
  final LatLng coord; // lat/lon

  const BusLinePoint({required this.point, required this.coord});
}

class BusLine {
  final String id;
  final String? name;

  /// Geometría principal en segmentos (como ya la usas en el mapa).
  final List<List<LatLng>> segments; // siempre 1 segmento en CSV

  /// Paradas (por ahora inicio/fin, luego tus paradas reales).
  final List<LatLng> stops;

  /// Geometría "plana" con el Point original del CSV.
  /// Útil para tests, depuración y para saber qué point es cada coord.
  final List<BusLinePoint> geometry;

  BusLine({
    required this.id,
    this.name,
    required this.segments,
    this.stops = const [],
    required this.geometry,
  });
}

class LinesRepository {
  // 🔴 Cache en memoria para no leer los CSV en cada búsqueda
  static List<BusLine>? _cache;

  /// Carga las líneas desde el catálogo JSON y lee cada CSV respetando el orden por "Point".
  Future<List<BusLine>> loadFromCatalog() async {
    // ✅ Si ya las cargamos una vez, devolvemos desde memoria
    if (_cache != null) return _cache!;

    // 1) Cargar catálogo
    final catStr = await rootBundle.loadString('assets/bus/lines_catalog.json');
    final Map<String, dynamic> catalog = jsonDecode(catStr);

    final out = <BusLine>[];

    for (final entry in catalog.entries) {
      final lineId = entry.key; // p.ej. "linea1"
      final map = entry.value as Map<String, dynamic>;
      final src = (map['source'] ?? '').toString(); // p.ej. "linea1.csv"
      if (src.isEmpty) continue;

      // 2) Cargar CSV
      final csvPath = 'assets/bus/csv/$src';
      final csvStr = await rootBundle.loadString(csvPath);

      // 3) Parse robusto:
      //    - Salta encabezado
      //    - Extrae los 3 primeros tokens numéricos por fila: point, lat, lon
      //    - Ordena por point (ascendente)
      final points = <_PointRow>[];
      final lines = csvStr
          .split(RegExp(r'\r?\n'))
          .where((l) => l.trim().isNotEmpty);

      bool isFirst = true;
      for (final raw in lines) {
        final row = raw.trim();
        if (isFirst) {
          isFirst = false;
          continue;
        } // salta header

        // Extrae tokens (permitimos comillas, espacios, etc.)
        final numTokens = RegExp(
          r'[-+]?\d+(\.\d+)?',
        ).allMatches(row).map((m) => m.group(0)!).toList();

        if (numTokens.length < 3) continue;

        final idx = int.tryParse(numTokens[0]);
        final lat = double.tryParse(numTokens[1]);
        final lon = double.tryParse(numTokens[2]);
        if (idx == null || lat == null || lon == null) continue;

        points.add(_PointRow(point: idx, lat: lat, lon: lon));
      }

      // 4) Ordenar por Point (1,2,3,...)
      points.sort((a, b) => a.point.compareTo(b.point));

      // 5) Construir geometría con Point + LatLng
      final geometry = <BusLinePoint>[
        for (final p in points)
          BusLinePoint(point: p.point, coord: LatLng(p.lat, p.lon)),
      ];

      // 6) Segmento en orden (como ya lo venías usando)
      final segment = <LatLng>[for (final gp in geometry) gp.coord];

      // 7) Paradas provisionales: inicio y fin
      final stops = <LatLng>[];
      if (segment.isNotEmpty) {
        stops.add(segment.first);
        if (segment.length > 1) stops.add(segment.last);
      }

      out.add(
        BusLine(
          id: lineId,
          name: lineId, // o un display name si luego lo agregas al catálogo
          segments: [segment],
          stops: stops,
          geometry: geometry,
        ),
      );
    }

    // 🔴 Guardamos en cache para las siguientes llamadas
    _cache = out;
    return out;
  }
}

class _PointRow {
  final int point;
  final double lat;
  final double lon;
  _PointRow({required this.point, required this.lat, required this.lon});
}
