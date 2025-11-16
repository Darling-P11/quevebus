import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:quevebus/core/services/itinerary_engine.dart';

class TravelScreen extends StatefulWidget {
  final ItineraryOption option;
  const TravelScreen({super.key, required this.option});

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  final MapController _map = MapController();

  LatLng? _myPos;
  bool _loading = true;
  String? _error;

  int _currentLegIndex = 0; // tramo actual (walk / bus)

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

      final pos = await Geolocator.getCurrentPosition();
      _myPos = LatLng(pos.latitude, pos.longitude);

      _fitRoute();

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _fitRoute() {
    final pts = <LatLng>[];
    for (final leg in widget.option.legs) {
      pts.addAll(leg.points);
    }
    if (_myPos != null) pts.add(_myPos!);
    if (pts.isEmpty) return;

    final b = LatLngBounds.fromPoints(pts);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: b,
        padding: const EdgeInsets.fromLTRB(24, 140, 24, 260),
      ),
    );
  }

  void _goStep(int delta) {
    final maxIndex = widget.option.legs.length - 1;
    setState(() {
      _currentLegIndex = (_currentLegIndex + delta).clamp(
        0,
        maxIndex,
      ); // anterior/siguiente
    });
  }

  String _buildInstruction() {
    if (widget.option.legs.isEmpty) return 'Sin información de viaje.';
    final leg = widget.option.legs[_currentLegIndex];

    if (leg.mode == 'walk') {
      // ¿hacia dónde camina?
      if (leg.boardStop != null && leg.alightStop == null) {
        return 'Camina hasta la parada de la línea ${leg.boardStop!.lineId}.';
      } else if (leg.alightStop != null && leg.boardStop == null) {
        return 'Camina desde la parada hasta tu destino.';
      } else if (leg.boardStop != null && leg.alightStop != null) {
        return 'Camina para hacer el trasbordo entre líneas.';
      }
      return 'Camina siguiendo la ruta indicada.';
    } else {
      final line = leg.lineId ?? 'bus';
      final toStop = leg.alightStop != null
          ? 'bájate en la parada #${leg.alightStop!.index}'
          : 'sigue hasta la parada indicada';
      return 'Toma la línea $line y $toStop.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final instruction = _buildInstruction();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Viaje en curso'),
        actions: [
          IconButton(
            onPressed: _fitRoute,
            tooltip: 'Reencuadrar ruta',
            icon: const Icon(Icons.my_location_rounded),
          ),
          IconButton(
            onPressed: () => context.pop(), // por ahora solo vuelve
            tooltip: 'Finalizar viaje',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          // =============== MAPA ===============
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _myPos ?? const LatLng(-1.0286, -79.4594),
              initialZoom: 15,
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

              // Ruta completa del itinerario
              _TravelItineraryLayer(
                option: widget.option,
                currentLegIndex: _currentLegIndex,
              ),

              // Posición actual
              if (_myPos != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myPos!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // =============== BARRA SUPERIOR DE INSTRUCCIÓN ===============
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 6,
              color: cs.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      child: Icon(
                        widget.option.legs[_currentLegIndex].mode == 'walk'
                            ? Icons.directions_walk_rounded
                            : Icons.directions_bus_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        instruction,
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // =============== PANEL INFERIOR: PASOS DEL VIAJE ===============
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Pasos del viaje',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _goStep(-1),
                          icon: const Icon(Icons.skip_previous_rounded),
                          tooltip: 'Paso anterior',
                        ),
                        IconButton(
                          onPressed: () => _goStep(1),
                          icon: const Icon(Icons.skip_next_rounded),
                          tooltip: 'Siguiente paso',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.option.legs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final leg = widget.option.legs[i];
                          final isCurrent = i == _currentLegIndex;
                          final isWalk = leg.mode == 'walk';
                          final title = isWalk
                              ? 'Caminata'
                              : 'Línea ${leg.lineId ?? ""}';
                          final subtitle = isWalk
                              ? 'Entre tramos'
                              : 'Hasta parada #${leg.alightStop?.index ?? "-"}';

                          return GestureDetector(
                            onTap: () => setState(() {
                              _currentLegIndex = i;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 180,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? cs.primary.withOpacity(.12)
                                    : cs.surfaceVariant.withOpacity(.4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isCurrent
                                      ? cs.primary
                                      : Colors.transparent,
                                  width: 1.4,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isWalk
                                        ? Colors.grey.shade700
                                        : Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    child: Icon(
                                      isWalk
                                          ? Icons.directions_walk_rounded
                                          : Icons.directions_bus_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
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
              ),
            ),
          ),

          if (_loading)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_error != null)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
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
        ],
      ),
    );
  }
}

// ==================== CAPA DE RUTA EN EL MAPA ====================

class _TravelItineraryLayer extends StatelessWidget {
  final ItineraryOption option;
  final int currentLegIndex;
  const _TravelItineraryLayer({
    required this.option,
    required this.currentLegIndex,
  });

  @override
  Widget build(BuildContext context) {
    final polylines = <Polyline>[];
    final markers = <Marker>[];

    for (int i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      if (leg.points.isEmpty) continue;

      final isCurrent = i == currentLegIndex;

      if (leg.mode == 'walk') {
        polylines.add(
          Polyline(
            points: leg.points,
            strokeWidth: isCurrent ? 5 : 4,
            color: Colors.grey.shade700.withOpacity(isCurrent ? 1.0 : 0.7),
            isDotted: true,
          ),
        );
      } else {
        // HALO
        polylines.add(
          Polyline(
            points: leg.points,
            strokeWidth: isCurrent ? 14 : 12,
            color: Colors.blue.shade200.withOpacity(isCurrent ? .45 : .30),
          ),
        );
        // LÍNEA PRINCIPAL
        polylines.add(
          Polyline(
            points: leg.points,
            strokeWidth: isCurrent ? 7 : 6,
            color: isCurrent ? Colors.blue.shade800 : Colors.blue.shade600,
            strokeCap: StrokeCap.round,
          ),
        );

        // Paradas especiales (subida / bajada / trasbordo)
        if (leg.boardStop != null) {
          markers.add(_stopMarker(leg.boardStop!));
        }
        if (leg.alightStop != null) {
          markers.add(_stopMarker(leg.alightStop!));
        }

        // Paradas intermedias de la línea
        if (leg.stops.isNotEmpty) {
          for (final st in leg.stops) {
            if (st.index == leg.boardStop?.index ||
                st.index == leg.alightStop?.index)
              continue;
            markers.add(_smallStopMarker(st));
          }
        }
      }
    }

    // Nodos globales de trasbordo, por si acaso
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
  } else {
    color = Colors.red;
    icon = Icons.location_on_rounded;
  }

  return Marker(
    point: stop.point,
    width: 42,
    height: 42,
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Center(child: Icon(icon, size: 22, color: color)),
    ),
  );
}

Marker _smallStopMarker(ItineraryStop stop) {
  return Marker(
    point: stop.point,
    width: 26,
    height: 26,
    child: Builder(
      builder: (ctx) => GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(
                'Línea ${stop.lineId} • Parada #${stop.index}'
                '${stop.isTransfer ? " (Trasbordo)" : ""}',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          child: Center(
            child: Icon(Icons.circle, size: 10, color: Colors.blue.shade700),
          ),
        ),
      ),
    ),
  );
}
