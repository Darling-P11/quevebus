// lib/core/graph/graph.dart
import 'package:collection/collection.dart' show PriorityQueue;

import 'package:latlong2/latlong.dart';

enum EdgeMode { walk, bus }

class Node {
  final int id;
  final LatLng pos;
  Node(this.id, this.pos);
}

class Edge {
  final int from;
  final int to;
  final double costMinutes; // costo en minutos
  final EdgeMode mode;
  final String? lineId; // para BUS
  Edge({
    required this.from,
    required this.to,
    required this.costMinutes,
    required this.mode,
    this.lineId,
  });
}

class Graph {
  final List<Node> nodes = [];
  final List<List<Edge>> adj = [];
  int addNode(LatLng p) {
    final id = nodes.length;
    nodes.add(Node(id, p));
    adj.add([]);
    return id;
  }

  void addEdge(Edge e) => adj[e.from].add(e);
}

/// --- Geo helpers ---
final Distance _dist = const Distance();

double meters(LatLng a, LatLng b) => _dist(a, b);
double minutesWalk(double meters, {double mps = 1.25}) => (meters / mps) / 60.0;
double minutesBus(double meters, {double mps = 12.0}) => (meters / mps) / 60.0;

/// --- A* ---
class _PQEntry {
  final int node;
  final double f;
  _PQEntry(this.node, this.f);
}

List<int> aStar({
  required Graph g,
  required int start,
  required int goal,
  required double Function(int) heuristicMinutes,
}) {
  final n = g.nodes.length;
  final came = List<int?>.filled(n, null);
  final gScore = List<double>.filled(n, double.infinity);
  final fScore = List<double>.filled(n, double.infinity);
  gScore[start] = 0.0;
  fScore[start] = heuristicMinutes(start);

  final pq = PriorityQueue<_PQEntry>((a, b) => a.f.compareTo(b.f));
  pq.add(_PQEntry(start, fScore[start]));

  final inOpen = List<bool>.filled(n, false);
  inOpen[start] = true;

  while (pq.isNotEmpty) {
    final cur = pq.removeFirst().node;
    inOpen[cur] = false;

    if (cur == goal) {
      // reconstruir
      final path = <int>[];
      int? u = goal;
      while (u != null) {
        path.add(u);
        u = came[u];
      }
      return path.reversed.toList();
    }

    for (final e in g.adj[cur]) {
      final tentative = gScore[cur] + e.costMinutes;
      if (tentative < gScore[e.to]) {
        came[e.to] = cur;
        gScore[e.to] = tentative;
        fScore[e.to] = tentative + heuristicMinutes(e.to);
        if (!inOpen[e.to]) {
          pq.add(_PQEntry(e.to, fScore[e.to]));
          inOpen[e.to] = true;
        }
      }
    }
  }

  return []; // no hay ruta
}
