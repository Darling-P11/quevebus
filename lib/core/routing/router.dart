// lib/core/routing/router.dart
import 'package:latlong2/latlong.dart';
import '../graph/graph.dart';
import '../services/lines_repository.dart';
import 'models.dart';

class RouterOptions {
  final double nodeStepMeters; // separación entre nodos técnicos
  final double walkRadiusStartEnd; // radio para conectar inicio/fin a nodos
  final double walkRadiusTransfer; // radio para permitir trasbordos a pie
  final double transferPenaltyMin; // penalización por cambio de línea (min)

  const RouterOptions({
    this.nodeStepMeters = 300.0,
    this.walkRadiusStartEnd = 300.0,
    this.walkRadiusTransfer = 150.0,
    this.transferPenaltyMin = 3.0,
  });
}

class BusRouter {
  final List<BusLine> lines;
  final RouterOptions opts;

  BusRouter({required this.lines, this.opts = const RouterOptions()});

  // Discretiza segmentos en nodos cada ~nodeStepMeters
  List<List<LatLng>> _densify(List<LatLng> seg) {
    if (seg.length < 2) return [];
    final out = <List<LatLng>>[];
    final current = <LatLng>[];
    current.add(seg.first);
    for (int i = 1; i < seg.length; i++) {
      final a = current.last;
      final b = seg[i];
      final d = meters(a, b);
      if (d <= opts.nodeStepMeters) {
        current.add(b);
      } else {
        // insertar puntos intermedios
        final steps = (d / opts.nodeStepMeters).ceil();
        for (int s = 1; s <= steps; s++) {
          final t = s / steps;
          final p = LatLng(
            a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t,
          );
          current.add(p);
        }
      }
    }
    out.add(current);
    return out;
  }

  // Construye el grafo base con aristas BUS
  Graph buildBusGraph() {
    final g = Graph();
    // índice simple por línea: lista de node ids por segmento
    final Map<String, List<List<int>>> lineNodeIds = {};

    for (final line in lines) {
      final perSegments = <List<int>>[];
      for (final seg in line.segments) {
        final dens = _densify(seg);
        for (final poly in dens) {
          final ids = <int>[];
          for (final p in poly) {
            ids.add(g.addNode(p));
          }
          // conectar consecutivos como BUS
          for (int i = 0; i + 1 < ids.length; i++) {
            final a = g.nodes[ids[i]].pos;
            final b = g.nodes[ids[i + 1]].pos;
            final d = meters(a, b);
            final cost = minutesBus(d);
            g.addEdge(
              Edge(
                from: ids[i],
                to: ids[i + 1],
                costMinutes: cost,
                mode: EdgeMode.bus,
                lineId: line.id,
              ),
            );
          }
          perSegments.add(ids);
        }
      }
      lineNodeIds[line.id] = perSegments;
    }
    return g;
  }

  // Conecta caminatas para trasbordos y para inicio/fin
  void connectWalking(Graph g, {LatLng? start, LatLng? goal}) {
    // índice espacial simplísimo: escanear todos (optimizable con grid)
    int? startId;
    int? goalId;

    if (start != null) {
      startId = g.addNode(start);
      for (final node in g.nodes) {
        if (node.id == startId) continue;
        final d = meters(start, node.pos);
        if (d <= opts.walkRadiusStartEnd) {
          g.addEdge(
            Edge(
              from: startId,
              to: node.id,
              costMinutes: minutesWalk(d),
              mode: EdgeMode.walk,
            ),
          );
        }
      }
    }

    if (goal != null) {
      goalId = g.addNode(goal);
      for (final node in g.nodes) {
        if (node.id == goalId) continue;
        final d = meters(node.pos, goal);
        if (d <= opts.walkRadiusStartEnd) {
          g.addEdge(
            Edge(
              from: node.id,
              to: goalId,
              costMinutes: minutesWalk(d),
              mode: EdgeMode.walk,
            ),
          );
        }
      }
    }

    // Trasbordos WALK entre nodos cercanos (≤ walkRadiusTransfer).
    // (MVP: escaneo O(n^2); luego pasamos a grid/kd-tree)
    final n = g.nodes.length;
    for (int i = 0; i < n; i++) {
      final pi = g.nodes[i].pos;
      for (int j = i + 1; j < n; j++) {
        final pj = g.nodes[j].pos;
        final d = meters(pi, pj);
        if (d <= opts.walkRadiusTransfer) {
          final m = minutesWalk(d);
          g.addEdge(Edge(from: i, to: j, costMinutes: m, mode: EdgeMode.walk));
          g.addEdge(Edge(from: j, to: i, costMinutes: m, mode: EdgeMode.walk));
        }
      }
    }
  }

  Itinerary? route(LatLng start, LatLng goal) {
    final g = buildBusGraph();
    // Guardamos ids antes de agregar start/goal
    final startIdx = g.nodes.length; // próximo id
    connectWalking(g, start: start, goal: goal);
    final realStart = startIdx; // start agregado
    final realGoal = g.nodes.length - 1; // goal es el último agregado

    double heuristic(int nodeId) {
      final p = g.nodes[nodeId].pos;
      final d = meters(p, g.nodes[realGoal].pos);
      // heurística optimista: suponiendo ir “rápido”
      return (d / 20.0) / 60.0; // 20 m/s ~ 72 km/h
    }

    final path = aStar(
      g: g,
      start: realStart,
      goal: realGoal,
      heuristicMinutes: heuristic,
    );
    if (path.isEmpty) return null;

    // Convertir path → legs (colapsar por modo y por línea si es BUS)
    final legs = <Leg>[];
    EdgeMode? curMode;
    String? curLine;
    final shape = <LatLng>[];
    double acc = 0.0;

    LatLng nodePos(int idx) => g.nodes[idx].pos;

    for (int i = 0; i + 1 < path.length; i++) {
      final u = path[i];
      final v = path[i + 1];

      // encontrar la arista usada (entre varias posibles escogemos la de menor costo)
      Edge? best;
      for (final e in g.adj[u]) {
        if (e.to == v) {
          if (best == null || e.costMinutes < best.costMinutes) best = e;
        }
      }
      if (best == null) continue;

      final mode = best.mode;
      final line = best.lineId;

      final segA = nodePos(u);
      final segB = nodePos(v);
      if (curMode == null) {
        curMode = mode;
        curLine = line;
        shape.add(segA);
      }

      final switching =
          (mode != curMode) || (mode == EdgeMode.bus && curLine != line);
      if (switching) {
        // cerrar tramo previo
        if (shape.isNotEmpty) {
          shape.add(nodePos(u));
          legs.add(
            Leg(
              mode: curMode == EdgeMode.walk ? LegMode.walk : LegMode.bus,
              lineId: curLine,
              shape: List<LatLng>.from(shape),
              minutes: acc,
            ),
          );
        }
        // abrir nuevo tramo
        curMode = mode;
        curLine = line;
        shape
          ..clear()
          ..add(nodePos(u));
        acc = 0.0;
      }

      acc += best.costMinutes;
      shape.add(segB);

      // penalización por trasbordo cuando cambia de línea BUS→BUS
      if (mode == EdgeMode.bus && curLine == line && switching) {
        acc += opts.transferPenaltyMin;
      }
    }

    if (shape.length >= 2 && curMode != null) {
      legs.add(
        Leg(
          mode: curMode == EdgeMode.walk ? LegMode.walk : LegMode.bus,
          lineId: curMode == EdgeMode.bus ? curLine : null,
          shape: List<LatLng>.from(shape),
          minutes: acc,
        ),
      );
    }

    return Itinerary(legs);
  }
}
