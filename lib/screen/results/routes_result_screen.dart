// lib/screen/results/routes_result_screen.dart
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
        // Caminata: punteado hasta la parada (y en trasbordos)
        polylines.add(
          Polyline(
            points: leg.points,
            strokeWidth: 4,
            color: Colors.grey.shade700.withOpacity(.9),
            isDotted: true, // 👈 punteado
          ),
        );
      } else {
        // Bus: ruta definida de la línea entre board y alight
        polylines.add(
          Polyline(
            points: leg.points,
            strokeWidth: 6,
            color: const Color(0xFF0D47A1),
          ),
        );
        // Pines de subida/bajada
        if (leg.boardStop != null) {
          markers.add(_busStop(leg.boardStop!, Colors.blue));
        }
        if (leg.alightStop != null) {
          markers.add(_busStop(leg.alightStop!, Colors.red));
        }
      }
    }

    // Paradas adicionales (por ejemplo nodos de transbordo)
    for (final s in option.allStops) {
      markers.add(_busStop(s, Colors.red));
    }

    return Stack(
      children: [
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Marker _busStop(LatLng p, Color color) => Marker(
    point: p,
    width: 24,
    height: 24,
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Center(
        child: Icon(
          Icons.directions_bus_filled_rounded,
          size: 14,
          color: color,
        ),
      ),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18)],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 8),
          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No se encontraron combinaciones de líneas cercanas.',
              ),
            ),
          if (options.isNotEmpty)
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final op = options[i];
                  final lines = op.lines.join('  ›  ');
                  final legs = op.legs
                      .map((l) => l.mode == 'walk' ? '🚶' : '🚌 ${l.lineId}')
                      .join('  •  ');
                  return Card(
                    child: ListTile(
                      onTap: () => onSelect(i),
                      leading: CircleAvatar(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        child: const Icon(Icons.directions_bus_rounded),
                      ),
                      title: Text(
                        lines,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(legs),
                      trailing: FilledButton.tonal(
                        onPressed: () => onSelect(i),
                        child: const Text('Detalles'),
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
