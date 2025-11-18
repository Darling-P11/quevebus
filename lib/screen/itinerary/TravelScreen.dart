// lib/screen/itinerary/travel_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_tts/flutter_tts.dart';

import 'package:quevebus/core/services/itinerary_engine.dart';
import 'package:quevebus/core/services/street_router.dart';

class TravelScreen extends StatefulWidget {
  final ItineraryOption option;
  const TravelScreen({super.key, required this.option});

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  // ---------- MAPA ----------
  GoogleMapController? _gMap;
  final ll.Distance _dist = const ll.Distance();

  // Copia mutable de la opción seleccionada
  late ItineraryOption _option;

  ll.LatLng? _myPos; // posición actual (latlong2)
  double _bearing = 0; // orientación en grados
  bool _followUser = true; // la cámara sigue a la persona

  bool _loading = true;
  String? _error;

  int _currentLegIndex = 0; // tramo actual (walk / bus)

  // Estadísticas de viaje
  double _totalMeters = 0;
  int _etaMinutes = 0;

  // Distancia al siguiente objetivo (parada / destino)
  double? _metersToTarget;

  // Suscripción al stream del GPS
  StreamSubscription<Position>? _posSub;

  // TTS
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  String? _lastSpoken;

  // Para no repetir avisos o recálculos
  final Set<int> _alertedLegs = {};
  bool _rerouting = false;

  @override
  void initState() {
    super.initState();
    _option = widget.option;
    _boot();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  // ======================== INICIALIZACIÓN ========================

  Future<void> _initTts() async {
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.6); // 🔊 Más despacio
    await _tts.setPitch(1.0);
    _ttsReady = true;
  }

  Future<void> _speak(String text) async {
    if (!_ttsReady) return;
    if (_lastSpoken == text) return;
    _lastSpoken = text;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _boot() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      await _initTts();

      // Posición inicial
      final pos = await Geolocator.getCurrentPosition();
      _myPos = ll.LatLng(pos.latitude, pos.longitude);
      _bearing = pos.heading.isNaN ? 0 : pos.heading;

      _computeStats();
      _updateLegAndTarget();
      _speak(_buildInstruction());

      // Escuchar el GPS en tiempo real
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5, // cada ~5m
        ),
      ).listen(_onPositionUpdate);

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

  // ======================== CÁLCULOS DE RUTA ========================

  void _computeStats() {
    double total = 0;
    double seconds = 0;

    const walkSpeed = 1.3; // m/s (~4.7 km/h)
    const busSpeed = 7.0; // m/s (~25 km/h)

    for (final leg in _option.legs) {
      double len = 0;
      for (int i = 1; i < leg.points.length; i++) {
        len += _dist(leg.points[i - 1], leg.points[i]);
      }
      total += len;

      final v = leg.mode == 'walk' ? walkSpeed : busSpeed;
      if (v > 0) {
        seconds += len / v;
      }
    }

    _totalMeters = total;
    _etaMinutes = (seconds / 60).round();
  }

  // Convierte latlong2 → Google LatLng
  LatLng _gm(ll.LatLng p) => LatLng(p.latitude, p.longitude);

  // Crea bounds para centrar toda la ruta
  LatLngBounds _boundsFromPoints(List<ll.LatLng> pts) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = (minLat == null)
          ? p.latitude
          : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = (maxLat == null)
          ? p.latitude
          : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = (minLng == null)
          ? p.longitude
          : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = (maxLng == null)
          ? p.longitude
          : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  // Centra la cámara en toda la ruta (botón “ver ruta completa”)
  void _fitRoute() {
    if (_gMap == null) return;
    final pts = <ll.LatLng>[];
    for (final leg in _option.legs) {
      pts.addAll(leg.points);
    }
    if (pts.isEmpty) return;

    final bounds = _boundsFromPoints(pts);
    _gMap!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  // Centra la cámara sobre la persona con estilo navegación
  void _moveCameraToUser({bool force = false}) {
    if (_gMap == null || _myPos == null) return;
    if (!_followUser && !force) return;

    final cam = CameraPosition(
      target: _gm(_myPos!),
      zoom: 17.0,
      bearing: _bearing, // orienta el mapa según la marcha
      tilt: 45.0,
    );
    _gMap!.animateCamera(CameraUpdate.newCameraPosition(cam));
  }

  // ======================== ACTUALIZACIÓN GPS ========================

  void _onPositionUpdate(Position p) {
    final prevLeg = _currentLegIndex;

    _myPos = ll.LatLng(p.latitude, p.longitude);
    if (!p.heading.isNaN && p.heading >= 0) {
      _bearing = p.heading;
    }

    _updateLegAndTarget();
    _moveCameraToUser();

    if (mounted) {
      setState(() {});
    }

    if (_currentLegIndex != prevLeg) {
      _speak(_buildInstruction());
    }
  }

  /// Reemplaza un tramo caminando con un nuevo ruteo a calles
  Future<void> _rerouteWalkingLeg(
    int idx,
    ll.LatLng from,
    ll.LatLng target,
  ) async {
    if (_rerouting) return;
    _rerouting = true;

    try {
      final newPoints = await StreetRouter.instance.routeByStreets([
        from,
        target,
      ]);

      if (newPoints.length < 2) {
        _rerouting = false;
        return;
      }

      final old = _option.legs[idx];
      final newLeg = ItineraryLeg(
        mode: old.mode,
        lineId: old.lineId,
        points: newPoints,
        boardStop: old.boardStop,
        alightStop: old.alightStop,
      );

      final newLegs = [..._option.legs];
      newLegs[idx] = newLeg;

      _option = ItineraryOption(
        legs: newLegs,
        allStops: _option.allStops,
        lines: _option.lines,
      );

      _computeStats();
      if (mounted) setState(() {});
      _speak('Se ha recalculado la ruta a pie.');
    } catch (_) {
      // silencioso
    } finally {
      _rerouting = false;
    }
  }

  /// Determina el tramo más cercano y calcula distancia al siguiente objetivo.
  /// También dispara recálculo si te desvías mucho en tramos a pie.
  void _updateLegAndTarget() {
    final pos = _myPos;
    if (pos == null || _option.legs.isEmpty) return;

    // 1) Buscar tramo más cercano a la posición actual
    int bestLeg = _currentLegIndex;
    double bestD = double.infinity;

    for (int i = 0; i < _option.legs.length; i++) {
      final leg = _option.legs[i];
      for (final pt in leg.points) {
        final d = _dist(pos, pt);
        if (d < bestD) {
          bestD = d;
          bestLeg = i;
        }
      }
    }

    _currentLegIndex = bestLeg;

    // 2) Objetivo del tramo (parada / destino)
    final leg = _option.legs[_currentLegIndex];
    ll.LatLng? target;

    if (leg.mode == 'walk') {
      if (leg.boardStop != null && leg.alightStop == null) {
        target = leg.boardStop!.point; // caminata origen → parada
      } else if (leg.alightStop != null && leg.boardStop == null) {
        target = leg.alightStop!.point; // caminata parada → destino
      } else if (leg.alightStop != null) {
        target = leg.alightStop!.point; // caminata entre paradas (trasbordo)
      } else if (leg.points.isNotEmpty) {
        target = leg.points.last;
      }
    } else {
      // tramo en bus → objetivo es la parada de bajada
      target =
          leg.alightStop?.point ??
          (leg.points.isNotEmpty ? leg.points.last : null);
    }

    if (target != null) {
      final m = _dist(pos, target);
      _metersToTarget = m;

      // 3) Aviso: prepárate para bajar
      if (leg.mode == 'bus' &&
          !_alertedLegs.contains(_currentLegIndex) &&
          m < 80) {
        _alertedLegs.add(_currentLegIndex);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Prepárate para bajar en la siguiente parada.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        _speak('Prepárate para bajar en la siguiente parada.');
      }

      // 4) Si ya estás muy cerca del objetivo, pasar al siguiente tramo
      if (m < 20 && _currentLegIndex < _option.legs.length - 1) {
        _currentLegIndex++;
        _metersToTarget = null;
      }

      // 5) Si es tramo caminando y estás MUY lejos de la ruta, recalcular
      if (leg.mode == 'walk') {
        double minToPolyline = double.infinity;
        for (final pt in leg.points) {
          final d = _dist(pos, pt);
          if (d < minToPolyline) minToPolyline = d;
        }

        // Umbral de desvío: > 60 m fuera del camino
        if (minToPolyline > 60) {
          _rerouteWalkingLeg(_currentLegIndex, pos, target);
        }
      }
    } else {
      _metersToTarget = null;
    }
  }

  // ======================== UI AUXILIAR ========================

  void _goStep(int delta) {
    final maxIndex = _option.legs.length - 1;
    setState(() {
      _currentLegIndex = (_currentLegIndex + delta).clamp(0, maxIndex);
    });
    _speak(_buildInstruction());
  }

  String _formatMeters(double m) {
    if (m < 1000) return '${m.toStringAsFixed(0)} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  String _buildInstruction() {
    if (_option.legs.isEmpty) return 'Sin información de viaje.';
    final leg = _option.legs[_currentLegIndex];
    final d = _metersToTarget;
    final distText = d != null ? ' (${_formatMeters(d)} restantes)' : '';

    if (leg.mode == 'walk') {
      if (leg.boardStop != null && leg.alightStop == null) {
        return 'Camina hasta la parada de la línea ${leg.boardStop!.lineId}$distText.';
      } else if (leg.alightStop != null && leg.boardStop == null) {
        return 'Camina desde la parada hasta tu destino$distText.';
      } else if (leg.boardStop != null && leg.alightStop != null) {
        return 'Camina para hacer el trasbordo entre líneas$distText.';
      }
      return 'Camina siguiendo la ruta indicada$distText.';
    } else {
      final line = leg.lineId ?? 'bus';
      final toStop = leg.alightStop != null
          ? 'bájate en la parada #${leg.alightStop!.index}'
          : 'sigue hasta la parada indicada';
      return 'Toma la línea $line y $toStop$distText.';
    }
  }

  // ----------------- Polylines, marcadores y “puntos blancos” -----------------

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};
    int id = 0;

    for (int i = 0; i < _option.legs.length; i++) {
      final leg = _option.legs[i];
      if (leg.points.length < 2) continue;

      final isCurrent = i == _currentLegIndex;
      final pts = leg.points.map(_gm).toList();

      if (leg.mode == 'walk') {
        polylines.add(
          Polyline(
            polylineId: PolylineId('leg_walk_$id'),
            points: pts,
            width: isCurrent ? 7 : 5,
            color: Colors.grey.shade700,
            patterns: [PatternItem.dash(20), PatternItem.gap(12)],
          ),
        );
      } else {
        polylines.add(
          Polyline(
            polylineId: PolylineId('leg_bus_$id'),
            points: pts,
            width: isCurrent ? 10 : 8,
            color: isCurrent ? Colors.blue.shade800 : Colors.blue.shade600,
          ),
        );
      }

      id++;
    }

    return polylines;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Paradas de cada tramo (solo bus)
    for (final leg in _option.legs) {
      if (leg.mode != 'bus') continue;

      if (leg.boardStop != null) {
        markers.add(_stopMarker(leg.boardStop!, isBoarding: true));
      }
      if (leg.alightStop != null) {
        markers.add(_stopMarker(leg.alightStop!, isBoarding: false));
      }
    }

    // Paradas globales (por si alguna de trasbordo no se incluyó arriba)
    for (final s in _option.allStops) {
      markers.add(_stopMarker(s, isBoarding: false));
    }

    return markers;
  }

  Marker _stopMarker(ItineraryStop stop, {required bool isBoarding}) {
    // Iconos:
    //  - Verde  = subida
    //  - Rojo   = bajada
    //  - Morado = trasbordo
    BitmapDescriptor icon;
    if (stop.isTransfer) {
      icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    } else if (isBoarding) {
      icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else {
      icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }

    final snippet = StringBuffer(
      'Línea ${stop.lineId} • Parada #${stop.index}',
    );
    if (stop.isTransfer) {
      snippet.write(' (trasbordo)');
    }

    return Marker(
      markerId: MarkerId(
        'stop_${stop.lineId}_${stop.index}_${isBoarding}_${stop.isTransfer}',
      ),
      position: _gm(stop.point),
      icon: icon,
      infoWindow: InfoWindow(
        title: stop.isTransfer
            ? 'Parada de trasbordo'
            : (isBoarding ? 'Parada de subida' : 'Parada de bajada'),
        snippet: snippet.toString(),
      ),
    );
  }

  /// Puntos blancos para sugerir paradas intermedias a lo largo del bus
  Set<Circle> _buildCircles() {
    final circles = <Circle>{};
    int cid = 0;

    for (final leg in _option.legs) {
      if (leg.mode != 'bus') continue;

      final pts = leg.points;
      // Tomamos cada 4º punto como "parada sugerida"
      for (int i = 2; i < pts.length - 2; i += 4) {
        final p = pts[i];
        circles.add(
          Circle(
            circleId: CircleId('hint_${cid++}'),
            center: _gm(p),
            radius: 7, // metros
            strokeWidth: 2,
            strokeColor: Colors.blueGrey.shade100,
            fillColor: Colors.white.withOpacity(0.95),
          ),
        );
      }
    }

    return circles;
  }

  // ======================== BUILD ========================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final instruction = _buildInstruction();

    final initialTarget = _myPos != null
        ? _gm(_myPos!)
        : const LatLng(-1.0286, -79.4594);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Viaje en curso'),
        actions: [
          // 🔵 Seguir ubicación (modo navegación)
          IconButton(
            onPressed: () {
              _followUser = true;
              _moveCameraToUser(force: true);
            },
            tooltip: 'Seguir mi ubicación',
            icon: const Icon(Icons.navigation_rounded),
          ),
          // 🔵 Ver ruta completa
          IconButton(
            onPressed: _fitRoute,
            tooltip: 'Ver ruta completa',
            icon: const Icon(Icons.map_rounded),
          ),
          // 🔵 Finalizar viaje
          IconButton(
            onPressed: () => context.pop(),
            tooltip: 'Finalizar viaje',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          // =============== MAPA GOOGLE ===============
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 15,
            ),
            onMapCreated: (ctrl) {
              _gMap = ctrl;
              // cuando el mapa está listo y ya tenemos posición, centra en la persona
              if (_myPos != null) {
                _moveCameraToUser(force: true);
              }
            },
            polylines: _buildPolylines(),
            markers: _buildMarkers(),
            circles: _buildCircles(),
            myLocationEnabled: true, // icono azul de Google
            myLocationButtonEnabled: false,
            compassEnabled: false,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            zoomControlsEnabled: false,
            onCameraMove: (_) {
              // si el usuario mueve el mapa a mano, dejamos de seguirlo
              _followUser = false;
            },
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
                        _option.legs[_currentLegIndex].mode == 'walk'
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

          // =============== PANEL INFERIOR: PASOS + ESTADÍSTICAS ===============
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

                    // Distancia total y tiempo estimado
                    Row(
                      children: [
                        Icon(Icons.route_rounded, size: 18, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Distancia: ${_formatMeters(_totalMeters)}',
                          style: TextStyle(fontSize: 13, color: cs.onSurface),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.access_time_filled_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tiempo estimado: $_etaMinutes min',
                          style: TextStyle(fontSize: 13, color: cs.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

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
                        itemCount: _option.legs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final leg = _option.legs[i];
                          final isCurrent = i == _currentLegIndex;
                          final isWalk = leg.mode == 'walk';
                          final title = isWalk
                              ? 'Caminata'
                              : 'Línea ${leg.lineId ?? ""}';
                          final subtitle = isWalk
                              ? 'Entre tramos'
                              : 'Hasta parada #${leg.alightStop?.index ?? "-"}';

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentLegIndex = i;
                              });
                              _speak(_buildInstruction());
                            },
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
