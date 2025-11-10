// lib/core/services/itinerary_engine.dart
import 'package:latlong2/latlong.dart';
import 'package:quevebus/core/services/lines_repository.dart';
import 'package:quevebus/core/services/street_router.dart';

class ItineraryLeg {
  final String mode; // walk | bus
  final String? lineId; // si mode=bus
  final List<LatLng> points; // polyline por calles
  final LatLng? boardStop; // parada de subida (si bus)
  final LatLng? alightStop; // parada de bajada (si bus)
  ItineraryLeg({
    required this.mode,
    this.lineId,
    required this.points,
    this.boardStop,
    this.alightStop,
  });
}

class ItineraryOption {
  final List<ItineraryLeg>
  legs; // 1 a 3 legs (walk-bus-[walk] o walk-bus-walk-bus-walk)
  final List<LatLng>
  allStops; // paradas que se muestran en mapa para esta opción
  final List<String> lines; // ids/nombres de líneas involucradas
  ItineraryOption({
    required this.legs,
    required this.allStops,
    required this.lines,
  });
}

class ItineraryEngine {
  final Distance _dist = const Distance();

  // encuentra la parada más cercana en una línea a un punto
  ({LatLng stop, int index, double meters}) _nearestStopInLine(
    BusLine line,
    LatLng p,
  ) {
    LatLng best = line.segments.first.first;
    int bestIdx = 0;
    double bestD = double.infinity;
    int idx = 0;
    for (final seg in line.segments) {
      for (final q in seg) {
        final d = _dist(p, q);
        if (d < bestD) {
          bestD = d;
          best = q;
          bestIdx = idx;
        }
        idx++;
      }
    }
    return (stop: best, index: bestIdx, meters: bestD);
  }

  // ¿la línea contiene ambas paradas en orden? (permite ida/retorno muy simples)
  bool _containsInOrder(BusLine l, LatLng a, LatLng b) {
    int i = -1, j = -1, k = 0;
    for (final seg in l.segments) {
      for (final p in seg) {
        if (i < 0 && _dist(p, a) < 10) i = k; // 10 m tolerancia
        if (j < 0 && _dist(p, b) < 10) j = k;
        k++;
      }
    }
    return (i >= 0 && j >= 0 && j > i);
  }

  // encuentra un punto de trasbordo entre 2 líneas (paradas muy cercanas)
  LatLng? _transferNode(BusLine a, BusLine b) {
    for (final segA in a.segments) {
      for (final pa in segA) {
        for (final segB in b.segments) {
          for (final pb in segB) {
            if (_dist(pa, pb) <= 25) return pa; // 25 m como nodo
          }
        }
      }
    }
    return null;
  }

  Future<List<ItineraryOption>> buildOptions({
    required List<BusLine> lines,
    required LatLng origin,
    required LatLng destination,
  }) async {
    final options = <ItineraryOption>[];

    // 1) Opciones de UNA sola línea
    for (final l in lines) {
      final nsO = _nearestStopInLine(l, origin);
      final nsD = _nearestStopInLine(l, destination);
      if (_containsInOrder(l, nsO.stop, nsD.stop)) {
        final walk1 = await StreetRouter.instance.routeByStreets([
          origin,
          nsO.stop,
        ]);
        final bus = await StreetRouter.instance.routeByStreets([
          nsO.stop,
          nsD.stop,
        ]);
        final walk2 = await StreetRouter.instance.routeByStreets([
          nsD.stop,
          destination,
        ]);

        options.add(
          ItineraryOption(
            legs: [
              if (walk1.isNotEmpty) ItineraryLeg(mode: 'walk', points: walk1),
              ItineraryLeg(
                mode: 'bus',
                lineId: l.id,
                points: bus,
                boardStop: nsO.stop,
                alightStop: nsD.stop,
              ),
              if (walk2.isNotEmpty) ItineraryLeg(mode: 'walk', points: walk2),
            ],
            allStops: [nsO.stop, nsD.stop],
            lines: [l.name ?? l.id],
          ),
        );
      }
    }

    // 2) Opciones con DOS líneas (un trasbordo)
    for (int i = 0; i < lines.length; i++) {
      for (int j = i + 1; j < lines.length; j++) {
        final a = lines[i], b = lines[j];
        final node = _transferNode(a, b);
        if (node == null) continue;

        final ao = _nearestStopInLine(a, origin);
        final bd = _nearestStopInLine(b, destination);

        // orden en A: origin->node ; orden en B: node->dest
        if (_containsInOrder(a, ao.stop, node) &&
            _containsInOrder(b, node, bd.stop)) {
          final walk1 = await StreetRouter.instance.routeByStreets([
            origin,
            ao.stop,
          ]);
          final busA = await StreetRouter.instance.routeByStreets([
            ao.stop,
            node,
          ]);
          final walkX =
              <
                LatLng
              >[]; // trasbordo en el mismo punto (si quisieras caminar, aquí)
          final busB = await StreetRouter.instance.routeByStreets([
            node,
            bd.stop,
          ]);
          final walk2 = await StreetRouter.instance.routeByStreets([
            bd.stop,
            destination,
          ]);

          options.add(
            ItineraryOption(
              legs: [
                if (walk1.isNotEmpty) ItineraryLeg(mode: 'walk', points: walk1),
                ItineraryLeg(
                  mode: 'bus',
                  lineId: a.id,
                  points: busA,
                  boardStop: ao.stop,
                  alightStop: node,
                ),
                if (walkX.isNotEmpty) ItineraryLeg(mode: 'walk', points: walkX),
                ItineraryLeg(
                  mode: 'bus',
                  lineId: b.id,
                  points: busB,
                  boardStop: node,
                  alightStop: bd.stop,
                ),
                if (walk2.isNotEmpty) ItineraryLeg(mode: 'walk', points: walk2),
              ],
              allStops: [ao.stop, node, bd.stop],
              lines: [a.name ?? a.id, b.name ?? b.id],
            ),
          );
        }
      }
    }

    // ordena por “longitud total” como proxy de duración
    options.sort((x, y) => _len(x).compareTo(_len(y)));
    return options;
  }

  double _len(ItineraryOption o) {
    double m = 0;
    for (final leg in o.legs) {
      for (int i = 1; i < leg.points.length; i++) {
        m += _dist(leg.points[i - 1], leg.points[i]);
      }
    }
    return m;
  }
}
