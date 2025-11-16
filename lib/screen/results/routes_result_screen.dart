import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import 'package:quevebus/core/services/lines_repository.dart';
import 'package:quevebus/core/services/street_router.dart';
import 'package:quevebus/core/services/itinerary_engine.dart';

class RoutesResultScreen extends StatefulWidget {
  final double? destLat;
  final double? destLon;
  const RoutesResultScreen({super.key, this.destLat, this.destLon});

  @override
  State<RoutesResultScreen> createState() => _RoutesResultScreenState();
}

class _RoutesResultScreenState extends State<RoutesResultScreen> {
  final MapController _map = MapController();

  LatLng? _origin;
  LatLng? _destination;

  List<LatLng> _routeOD = const [];
  List<ItineraryOption> _options = const [];
  int _selected = -1;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // 1) Origen (posición actual)
      final pos = await Geolocator.getCurrentPosition();
      _origin = LatLng(pos.latitude, pos.longitude);

      // 2) Destino
      final dlat = widget.destLat ?? pos.latitude;
      final dlon = widget.destLon ?? pos.longitude;
      _destination = LatLng(dlat, dlon);

      // 3) Ruteo completo O->D (azul base)
      _routeOD = await StreetRouter.instance.routeByStreets([
        _origin!,
        _destination!,
      ]);

      // 4) Construir sugerencias
      final lines = await LinesRepository().loadFromCatalog();
      _options = await ItineraryEngine().buildOptions(
        lines: lines,
        origin: _origin!,
        destination: _destination!,
      );

      setState(() {
        _loading = false;
      });
      _fitAll();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _fitAll() {
    final pts = <LatLng>[];
    if (_selected < 0 && _routeOD.isNotEmpty) pts.addAll(_routeOD);
    if (_selected >= 0 && _selected < _options.length) {
      for (final leg in _options[_selected].legs) {
        pts.addAll(leg.points);
      }
    }
    if (_origin != null) pts.add(_origin!);
    if (_destination != null) pts.add(_destination!);
    if (pts.isEmpty) return;

    final b = LatLngBounds.fromPoints(pts);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: b,
        padding: const EdgeInsets.fromLTRB(24, 140, 24, 260),
      ),
    );
  }

  void _focusOption(ItineraryOption op) {
    final pts = <LatLng>[];
    for (final leg in op.legs) {
      pts.addAll(leg.points);
    }
    if (pts.isEmpty) return;
    final b = LatLngBounds.fromPoints(pts);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: b,
        padding: const EdgeInsets.fromLTRB(24, 140, 24, 260),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Sugerencias de viaje'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            onPressed: _fitAll,
            tooltip: 'Reencuadrar',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ======================= MAPA =======================
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _origin ?? const LatLng(-1.0286, -79.4594),
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.quevebus',
                retinaMode: true,
              ),

              // Ruta O->D por calles (azul) SOLO si no hay selección
              if (_routeOD.isNotEmpty && _selected < 0)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routeOD,
                      strokeWidth: 6,
                      color: const Color(0xFF1565C0),
                    ),
                  ],
                ),

              // Itinerario seleccionado: caminado punteado y buses
              if (_selected >= 0 && _selected < _options.length)
                _ItineraryLayer(option: _options[_selected]),

              // Marcadores O/D
              if (_origin != null || _destination != null)
                MarkerLayer(
                  markers: [
                    if (_origin != null)
                      Marker(
                        point: _origin!,
                        width: 18,
                        height: 18,
                        child: _dot(Colors.green.shade600),
                      ),
                    if (_destination != null)
                      Marker(
                        point: _destination!,
                        width: 18,
                        height: 18,
                        child: _dot(Colors.black87),
                      ),
                  ],
                ),
            ],
          ),

          const Positioned(top: 80, right: 12, child: _LegendWidget()),

          // =================== ESTADO / ERRORES ===================
          if (_loading)
            const Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Calculando rutas…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_error != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                color: cs.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Error: $_error',
                    style: TextStyle(color: cs.onErrorContainer),
                  ),
                ),
              ),
            ),

          // ============== BOTTOM SHEET SCROLLABLE ==============
          if (!_loading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: MediaQuery.of(context).size.height * 0.35,
              child: SafeArea(
                top: false,
                child: DraggableScrollableSheet(
                  initialChildSize: 1,
                  minChildSize: 1,
                  maxChildSize: 1,
                  expand: true,
                  builder: (ctx, scrollCtrl) {
                    return _OptionsSheet(
                      options: _options,
                      onSelect: (i) {
                        setState(() => _selected = i);
                        _focusOption(_options[i]);
                      },
                      scrollController: scrollCtrl,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
    decoration: BoxDecoration(
      color: c,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
  );
}

// ---------- UI de itinerario sobre el mapa
class _ItineraryLayer extends StatelessWidget {
  final ItineraryOption option;
  const _ItineraryLayer({required this.option});

  @override
  Widget build(BuildContext context) {
    final polylines = <Polyline>[];
    final markers = <Marker>[];

    for (final leg in option.legs) {
      if (leg.points.isEmpty) continue;

      if (leg.mode == 'walk') {
        /// Caminata → estilo punteado elegante
        polylines.add(
          Polyline(
            points: leg.points,
            strokeWidth: 4,
            color: Colors.grey.shade700,
            isDotted: true,
          ),
        );
      } else {
        /// 🚌 Estilo Google Maps: LÍNEA + HALO
        polylines.add(
          Polyline(
            points: leg.points,
            strokeWidth: 12,
            color: Colors.blue.shade200.withOpacity(.35), // HALO
          ),
        );
        polylines.add(
          Polyline(
            points: leg.points,
            strokeWidth: 6,
            color: Colors.blue.shade600,
            strokeCap: StrokeCap.round,
          ),
        );

        // Pines de paradas (subida/bajada/trasbordo)
        if (leg.boardStop != null) {
          markers.add(_stopMarker(leg.boardStop!));
        }
        if (leg.alightStop != null) {
          markers.add(_stopMarker(leg.alightStop!));
        }
      }
    }

    // Paradas adicionales (trasbordos interlíneas)
    for (final s in option.allStops) {
      markers.add(_stopMarker(s));
    }

    return Stack(
      children: [
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

Marker _stopMarker(ItineraryStop stop) {
  late Color color;
  late IconData icon;

  if (stop.isTransfer) {
    color = Colors.deepPurple;
    icon = Icons.compare_arrows_rounded;
  } else if (stop.index < 4) {
    color = Colors.green;
    icon = Icons.arrow_upward_rounded;
  } else {
    color = Colors.red;
    icon = Icons.arrow_downward_rounded;
  }

  return Marker(
    point: stop.point,
    width: 42,
    height: 42,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Center(child: Icon(icon, size: 22, color: color)),
    ),
  );
}

// ---------- Tarjetas de opciones
class _OptionsSheet extends StatelessWidget {
  final List<ItineraryOption> options;
  final ValueChanged<int> onSelect;
  final ScrollController? scrollController;
  const _OptionsSheet({
    required this.options,
    required this.onSelect,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          const SizedBox(height: 12),

          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No se encontraron opciones cercanas.',
                style: TextStyle(fontSize: 16),
              ),
            ),

          if (options.isNotEmpty)
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final op = options[i];
                  final lines = op.lines.join(" → ");
                  final legs = op.legs
                      .map(
                        (l) =>
                            l.mode == 'walk' ? 'Caminata' : 'Línea ${l.lineId}',
                      )
                      .join('  •  ');

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelect(i),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceBright,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            child: const Icon(Icons.directions_bus_rounded),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lines,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  legs,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendWidget extends StatelessWidget {
  const _LegendWidget();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      color: Colors.white.withOpacity(.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(Icons.arrow_upward_rounded, Colors.green, "Subida"),
            _row(Icons.arrow_downward_rounded, Colors.red, "Bajada"),
            _row(Icons.compare_arrows_rounded, Colors.deepPurple, "Trasbordo"),
            _row(Icons.directions_walk_rounded, Colors.grey, "Caminata"),
            const SizedBox(height: 6),
            _lineBox(Colors.blue.shade600, "Ruta del bus"),
            _lineBox(Colors.blue.shade200, "Halo de ruta"),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, Color c, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _lineBox(Color c, String text) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 4,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
