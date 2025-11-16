// lib/core/services/itinerary_engine.dart
import 'package:latlong2/latlong.dart';
import 'package:quevebus/core/services/lines_repository.dart';
import 'package:quevebus/core/services/street_router.dart';

/// Parada dentro de una línea: punto, id de línea, índice y si es trasbordo.
class ItineraryStop {
  final LatLng point;
  final String lineId;
  final int index; // índice dentro de la geometría (Point del CSV)
  final bool isTransfer;

  const ItineraryStop({
    required this.point,
    required this.lineId,
    required this.index,
    this.isTransfer = false,
  });
}

class ItineraryLeg {
  final String mode; // walk | bus
  final String? lineId; // si mode = bus
  final List<LatLng> points; // polyline ruteada por calles
  final ItineraryStop? boardStop; // parada de subida (si bus)
  final ItineraryStop? alightStop; // parada de bajada (si bus)

  /// TODAS las paradas reales (points del CSV) que recorre este tramo de bus.
  final List<ItineraryStop> stops;

  ItineraryLeg({
    required this.mode,
    this.lineId,
    required this.points,
    this.boardStop,
    this.alightStop,
    this.stops = const [],
  });
}

class ItineraryOption {
  // 1 a 3 legs (walk-bus-[walk] o walk-bus-walk-bus-walk)
  final List<ItineraryLeg> legs;
  // paradas que se muestran en mapa para esta opción
  final List<ItineraryStop> allStops;
  // ids/nombres de líneas involucradas
  final List<String> lines;

  ItineraryOption({
    required this.legs,
    required this.allStops,
    required this.lines,
  });
}

class ItineraryEngine {
  final Distance _dist = const Distance();

  // Punto más cercano de la geometría de la línea a un punto dado.
  // Devuelve el punto, su índice global dentro de la línea y la distancia.
  ({LatLng stop, int index, double meters}) _nearestStopInLine(
    BusLine line,
    LatLng p,
  ) {
    LatLng? best;
    int bestIdx = -1;
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

    // Nunca debería ser null porque siempre hay al menos un punto,
    // pero por seguridad devolvemos el primero.
    best ??= line.segments.first.first;
    if (bestIdx < 0) bestIdx = 0;

    return (stop: best, index: bestIdx, meters: bestD);
  }

  // Aplana todos los segmentos de la línea en una sola lista de puntos.
  List<LatLng> _flattenSegments(BusLine line) {
    final out = <LatLng>[];
    for (final seg in line.segments) {
      out.addAll(seg);
    }
    return out;
  }

  // Devuelve el sub-tramo de la línea [line] entre los índices [from] y [to]
  // respetando el orden real del recorrido (Point 5 → 6 → … → 10).
  List<LatLng> _subsegment(BusLine line, int from, int to) {
    if (from < 0 || to < 0) return const [];
    if (to <= from) return const [];

    final flat = _flattenSegments(line);
    if (flat.isEmpty) return const [];

    final start = from.clamp(0, flat.length - 1);
    final end = to.clamp(0, flat.length - 1);
    if (end <= start) return const [];

    return flat.sublist(start, end + 1);
  }

  /// Sigue la calle entre cada par consecutivo del subtramo de la línea.
  /// Respeta el orden de la línea, pero ajusta cada salto al StreetRouter.
  Future<List<LatLng>> _routeBusSegmentAlongStreets(
    BusLine line,
    int from,
    int to,
  ) async {
    final base = _subsegment(line, from, to);
    if (base.length <= 1) return base;

    final out = <LatLng>[];

    for (int i = 0; i < base.length - 1; i++) {
      final a = base[i];
      final b = base[i + 1];

      // El primer punto siempre se agrega
      if (i == 0) {
        out.add(a);
      }

      final d = _dist(a, b);

      // Si están muy cerca, no vale la pena rutear, se añade directo.
      if (d < 15) {
        out.add(b);
        continue;
      }

      // Ruteamos el pequeño tramo A -> B respetando las calles
      final seg = await StreetRouter.instance.routeByStreets([a, b]);

      if (seg.length <= 1) {
        // Si no hay resultado útil, agregamos B directo
        out.add(b);
      } else {
        // Evitamos repetir el punto inicial (a) porque ya está en out
        out.addAll(seg.skip(1));
      }
    }

    return out;
  }

  // Detecta un "nodo" de transbordo entre dos líneas:
  // cualquier par de puntos a <= 25m se considera nodo.
  LatLng? _transferNode(BusLine a, BusLine b) {
    for (final segA in a.segments) {
      for (final pa in segA) {
        for (final segB in b.segments) {
          for (final pb in segB) {
            if (_dist(pa, pb) <= 25) {
              return pa; // 25 m como nodo
            }
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

    // =========================
    // 1) Opciones de UNA sola línea
    // =========================
    for (final l in lines) {
      final nsO = _nearestStopInLine(l, origin);
      final nsD = _nearestStopInLine(l, destination);

      // Aseguramos orden correcto en la geometría de la línea:
      // la parada de subida debe ir antes que la de bajada.
      if (nsO.index >= 0 && nsD.index > nsO.index) {
        final boardStop = ItineraryStop(
          point: nsO.stop,
          lineId: l.id,
          index: nsO.index,
          isTransfer: false,
        );
        final alightStop = ItineraryStop(
          point: nsD.stop,
          lineId: l.id,
          index: nsD.index,
          isTransfer: false,
        );

        // Caminata desde origen hasta la parada de subida
        final walk1 = await StreetRouter.instance.routeByStreets([
          origin,
          boardStop.point,
        ]);

        // 🚌 Tramo en bus (geometría ruteada por calles)
        final busPoints = await _routeBusSegmentAlongStreets(
          l,
          nsO.index,
          nsD.index,
        );

        // 👉 TODAS las paradas reales entre nsO y nsD
        final flat = _flattenSegments(l);
        final segmentStops = <ItineraryStop>[];
        for (int i = nsO.index; i <= nsD.index && i < flat.length; i++) {
          segmentStops.add(
            ItineraryStop(
              point: flat[i],
              lineId: l.id,
              index: i,
              isTransfer: false,
            ),
          );
        }

        // Caminata desde la parada de bajada hasta el destino
        final walk2 = await StreetRouter.instance.routeByStreets([
          alightStop.point,
          destination,
        ]);

        if (busPoints.isEmpty) continue;

        options.add(
          ItineraryOption(
            legs: [
              if (walk1.isNotEmpty) ItineraryLeg(mode: 'walk', points: walk1),
              ItineraryLeg(
                mode: 'bus',
                lineId: l.id,
                points: busPoints,
                boardStop: boardStop,
                alightStop: alightStop,
                stops: segmentStops, // 👈 AQUÍ van todas las paradas del tramo
              ),
              if (walk2.isNotEmpty) ItineraryLeg(mode: 'walk', points: walk2),
            ],
            allStops: [boardStop, alightStop],
            lines: [l.name ?? l.id],
          ),
        );
      }
    }

    // =========================
    // 2) Opciones con DOS líneas (un trasbordo)
    // =========================
    // =========================
    // 2) Opciones con DOS líneas (un trasbordo)
    // =========================
    for (int i = 0; i < lines.length; i++) {
      for (int j = i + 1; j < lines.length; j++) {
        final a = lines[i];
        final b = lines[j];

        final node = _transferNode(a, b);
        if (node == null) continue;

        // Puntos cercanos al origen y destino
        final ao = _nearestStopInLine(a, origin);
        final bd = _nearestStopInLine(b, destination);

        // Nodo proyectado en cada línea
        final an = _nearestStopInLine(a, node);
        final bn = _nearestStopInLine(b, node);

        // Validamos orden:
        //   en A: origen -> nodo
        //   en B: nodo -> destino
        final okA = ao.index >= 0 && an.index > ao.index;
        final okB = bn.index >= 0 && bd.index > bn.index;
        if (!okA || !okB) continue;

        final stopAO = ItineraryStop(
          point: ao.stop,
          lineId: a.id,
          index: ao.index,
          isTransfer: false,
        );
        final stopAN = ItineraryStop(
          point: an.stop,
          lineId: a.id,
          index: an.index,
          isTransfer: true, // 👈 aquí se baja del A
        );
        final stopBN = ItineraryStop(
          point: bn.stop,
          lineId: b.id,
          index: bn.index,
          isTransfer: true, // 👈 aquí se sube al B
        );
        final stopBD = ItineraryStop(
          point: bd.stop,
          lineId: b.id,
          index: bd.index,
          isTransfer: false,
        );

        // Caminata desde origen hasta parada de la línea A
        final walk1 = await StreetRouter.instance.routeByStreets([
          origin,
          stopAO.point,
        ]);

        // 🚌 Tramo en bus en la línea A: orden real A[ao.index .. an.index]
        final busA = await _routeBusSegmentAlongStreets(a, ao.index, an.index);

        // Caminata de trasbordo entre la bajada de A y subida de B
        final walkX = await StreetRouter.instance.routeByStreets([
          stopAN.point,
          stopBN.point,
        ]);

        // 🚌 Tramo en bus en la línea B: orden real B[bn.index .. bd.index]
        final busB = await _routeBusSegmentAlongStreets(b, bn.index, bd.index);

        // Caminata desde bajada de B hasta el destino
        final walk2 = await StreetRouter.instance.routeByStreets([
          stopBD.point,
          destination,
        ]);

        // 👉 stops reales del tramo A
        final flatA = _flattenSegments(a);
        final segmentStopsA = <ItineraryStop>[];
        for (int k = ao.index; k <= an.index && k < flatA.length; k++) {
          segmentStopsA.add(
            ItineraryStop(
              point: flatA[k],
              lineId: a.id,
              index: k,
              isTransfer: k == an.index, // en el nodo se hace trasbordo
            ),
          );
        }

        // 👉 stops reales del tramo B
        final flatB = _flattenSegments(b);
        final segmentStopsB = <ItineraryStop>[];
        for (int k = bn.index; k <= bd.index && k < flatB.length; k++) {
          segmentStopsB.add(
            ItineraryStop(
              point: flatB[k],
              lineId: b.id,
              index: k,
              isTransfer: k == bn.index, // aquí se sube al B
            ),
          );
        }

        if (busA.isEmpty || busB.isEmpty) continue;

        options.add(
          ItineraryOption(
            legs: [
              if (walk1.isNotEmpty) ItineraryLeg(mode: 'walk', points: walk1),
              ItineraryLeg(
                mode: 'bus',
                lineId: a.id,
                points: busA,
                boardStop: stopAO,
                alightStop: stopAN,
                stops: segmentStopsA, // 👈 todas las paradas del tramo A
              ),
              if (walkX.isNotEmpty) ItineraryLeg(mode: 'walk', points: walkX),
              ItineraryLeg(
                mode: 'bus',
                lineId: b.id,
                points: busB,
                boardStop: stopBN,
                alightStop: stopBD,
                stops: segmentStopsB, // 👈 todas las paradas del tramo B
              ),
              if (walk2.isNotEmpty) ItineraryLeg(mode: 'walk', points: walk2),
            ],
            allStops: [stopAO, stopAN, stopBN, stopBD],
            lines: [a.name ?? a.id, b.name ?? b.id],
          ),
        );
      }
    }

    // Ordenamos por longitud total (distancia recorrida)
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
