// lib/screen/lines/line_preview_screen.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:quevebus/core/services/lines_repository.dart';
import 'package:quevebus/core/services/street_router.dart';

class LinePreviewScreen extends StatefulWidget {
  final BusLine line;
  const LinePreviewScreen({super.key, required this.line});

  @override
  State<LinePreviewScreen> createState() => _LinePreviewScreenState();
}

class _LinePreviewScreenState extends State<LinePreviewScreen> {
  final MapController _mapCtrl = MapController();
  bool _mapReady = false;

  List<List<LatLng>> _segments = const [];
  List<LatLng> _allPoints = const [];
  List<LatLng> _stops = const [];
  List<BusLinePoint> _geometry = const []; // geometry con Point del CSV

  List<LatLng> _streetPolyline = const [];
  bool _streetLoading = true;
  bool _streetFailed = false;

  bool _showStops = true;
  double _zoom = 14;

  @override
  void initState() {
    super.initState();
    _prepareData();
    _buildStreetPolyline();
  }

  void _prepareData() {
    final line = widget.line;

    _segments = line.segments.isNotEmpty ? line.segments : [<LatLng>[]];

    final merged = <LatLng>[];
    for (final seg in _segments) {
      merged.addAll(seg);
    }
    _allPoints = merged;
    _stops =
        merged; // todas las coordenadas son paradas (inicio/fin se diferencian por icono)

    // geometry con Point del CSV, para saber qué punto es cada parada
    _geometry = line.geometry;
  }

  Future<void> _buildStreetPolyline() async {
    setState(() {
      _streetLoading = true;
      _streetFailed = false;
    });

    final poly = await StreetRouter.instance.routeByStreets(_stops);
    if (!mounted) return;

    setState(() {
      _streetPolyline = poly;
      _streetLoading = false;
      _streetFailed = poly.isEmpty;
    });

    _fitBounds();
  }

  void _onMapReady() {
    _mapReady = true;
    _fitBounds();
  }

  void _fitBounds() {
    if (!_mapReady) return;
    final pts = _streetPolyline.isNotEmpty ? _streetPolyline : _allPoints;
    if (pts.isEmpty) return;

    _mapCtrl.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
      ),
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Fallback lógico para esta pantalla
      context.go('/menu/lines-test');
    }
  }

  // ===== Helpers visuales / de parada =====
  List<LatLng> _sampledStops() {
    if (!_showStops) return const [];
    if (_stops.length <= 2) return _stops;

    int step;
    if (_zoom < 12) {
      step = 10;
    } else if (_zoom < 13.5) {
      step = 6;
    } else if (_zoom < 15.3) {
      step = 3;
    } else {
      step = 1;
    }

    final out = <LatLng>[];
    for (int i = 0; i < _stops.length; i += step) {
      out.add(_stops[i]);
    }
    if (out.isEmpty || out.first != _stops.first) out.insert(0, _stops.first);
    if (out.last != _stops.last) out.add(_stops.last);
    return out;
  }

  // Busca el BusLinePoint (con Point del CSV) que coincide con esta coord
  BusLinePoint? _findPoint(LatLng p) {
    try {
      return _geometry.firstWhere(
        (g) =>
            g.coord.latitude == p.latitude && g.coord.longitude == p.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  void _showStopInfo(BuildContext context, LatLng p) {
    final gp = _findPoint(p);
    final pointStr = gp != null ? gp.point.toString() : '?';
    final lineId = widget.line.id;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Línea $lineId · Point $pointStr'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  double _bearingRad(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return math.atan2(y, x);
  }

  List<Marker> _arrowMarkers(Color color) {
    final src = _streetPolyline.isNotEmpty ? _streetPolyline : _allPoints;
    if (src.length < 2) return const [];

    const everyN = 12;
    final arrows = <Marker>[];
    for (int i = 0; i < src.length - 1; i += everyN) {
      final a = src[i];
      final b = src[i + 1];
      final angle = _bearingRad(a, b);
      arrows.add(
        Marker(
          point: a,
          width: 26,
          height: 26,
          alignment: Alignment.center,
          child: Transform.rotate(
            angle: angle,
            child: Icon(
              Icons.navigation,
              size: 22,
              color: color.withOpacity(.95),
            ),
          ),
        ),
      );
    }
    return arrows;
  }

  Widget _roundIcon({
    required IconData icon,
    required Color color,
    double size = 22,
    double pad = 6,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        border: Border.all(color: Colors.black12, width: 1),
      ),
      padding: EdgeInsets.all(pad),
      child: Icon(icon, size: size, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = (widget.line.name?.isNotEmpty == true)
        ? widget.line.name!
        : 'Línea ${widget.line.id}';

    final totalPts = _allPoints.length;
    final nStops = _stops.length;
    final nSegs = _segments.length;

    // Colores del esquema para look moderno
    final routeMain = cs.primary;
    final routeCasing = cs.primaryContainer.withOpacity(.85);
    final arrowColor = cs.secondary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _handleBack,
        ),
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Reencuadrar',
            onPressed: _fitBounds,
            icon: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _allPoints.isNotEmpty
                  ? _allPoints.first
                  : const LatLng(-1.0286, -79.4594),
              initialZoom: 14.0,
              onMapReady: _onMapReady,
              onMapEvent: (e) {
                if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd) {
                  setState(() => _zoom = _mapCtrl.camera.zoom);
                }
              },
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

              // Ruta por calles con sombra + casing + trazo principal
              if (_streetPolyline.isNotEmpty) ...[
                PolylineLayer(
                  // sombra suave
                  polylines: [
                    Polyline(
                      points: _streetPolyline,
                      color: Colors.black.withOpacity(.20),
                      strokeWidth: 12,
                    ),
                  ],
                ),
                PolylineLayer(
                  // casing
                  polylines: [
                    Polyline(
                      points: _streetPolyline,
                      color: routeCasing,
                      strokeWidth: 9,
                    ),
                  ],
                ),
                PolylineLayer(
                  // trazo
                  polylines: [
                    Polyline(
                      points: _streetPolyline,
                      color: routeMain,
                      strokeWidth: 6,
                    ),
                  ],
                ),
              ],

              // Fallback: segmentos originales
              if (_streetPolyline.isEmpty)
                PolylineLayer(
                  polylines: [
                    for (final seg in _segments)
                      Polyline(points: seg, color: cs.outline, strokeWidth: 6),
                  ],
                ),

              // Flechas de dirección
              MarkerLayer(markers: _arrowMarkers(arrowColor)),

              // Paradas
              if (_showStops)
                MarkerLayer(
                  markers: () {
                    final mk = <Marker>[];

                    if (_allPoints.isNotEmpty) {
                      final pFirst = _allPoints.first;
                      mk.add(
                        Marker(
                          point: pFirst,
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () => _showStopInfo(context, pFirst),
                            child: _roundIcon(
                              icon: Icons.flag_rounded,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      );
                    }
                    if (_allPoints.length > 1) {
                      final pLast = _allPoints.last;
                      mk.add(
                        Marker(
                          point: pLast,
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () => _showStopInfo(context, pLast),
                            child: _roundIcon(
                              icon: Icons.flag_outlined,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      );
                    }

                    final sampled = _sampledStops();
                    for (final p in sampled) {
                      if (p == _allPoints.first || p == _allPoints.last) {
                        continue;
                      }
                      mk.add(
                        Marker(
                          point: p,
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () => _showStopInfo(context, p),
                            child: _roundIcon(
                              icon: Icons.directions_bus, // icono nativo
                              color: cs.tertiary,
                              size: 20,
                              pad: 5,
                            ),
                          ),
                        ),
                      );
                    }
                    return mk;
                  }(),
                ),

              // Regla de escala discreta
              Positioned(
                left: 12,
                bottom: 160,
                child: _SimpleScaleBar(mapCtrl: _mapCtrl),
              ),
            ],
          ),

          // Botones flotantes verticales (zoom / centrar) con glass
          Positioned(
            right: 12,
            top: 100,
            child: _GlassCol(
              children: [
                _FabIcon(
                  icon: Icons.add,
                  onTap: () => _mapCtrl.move(
                    _mapCtrl.camera.center,
                    _mapCtrl.camera.zoom + 1,
                  ),
                ),
                _FabIcon(
                  icon: Icons.remove,
                  onTap: () => _mapCtrl.move(
                    _mapCtrl.camera.center,
                    _mapCtrl.camera.zoom - 1,
                  ),
                ),
                _FabIcon(icon: Icons.my_location, onTap: _fitBounds),
              ],
            ),
          ),

          // Estado del ruteo (glass)
          if (_streetLoading)
            const _GlassToast(text: 'Calculando ruta por calles...'),
          if (_streetFailed && !_streetLoading)
            const _GlassToast(
              text: 'No se pudo rutear por calles (usando rectas).',
            ),
        ],
      ),
      bottomNavigationBar: _GlassBottomBar(
        child: Row(
          children: [
            const Icon(Icons.directions_bus_filled),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Segmentos: $nSegs  •Puntos: $totalPts  •Paradas: $nStops',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showStops = !_showStops),
              child: Text(_showStops ? 'Ocultar paradas' : 'Mostrar paradas'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _handleBack,
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Widgets “glass” reutilizables =====

class _GlassBottomBar extends StatelessWidget {
  final Widget child;
  const _GlassBottomBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.75),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: child,
        ),
      ),
    );
  }
}

class _GlassToast extends StatelessWidget {
  final String text;
  const _GlassToast({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white.withOpacity(.75),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCol extends StatelessWidget {
  final List<Widget> children;
  const _GlassCol({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: Colors.white.withOpacity(.7),
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                children.expand((w) => [w, const SizedBox(height: 6)]).toList()
                  ..removeLast(),
          ),
        ),
      ),
    );
  }
}

class _GlassRow extends StatelessWidget {
  final List<Widget> children;
  const _GlassRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: Colors.white.withOpacity(.7),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children:
                children.expand((w) => [w, const SizedBox(width: 6)]).toList()
                  ..removeLast(),
          ),
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _LegendChip({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FabIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FabIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

class _SimpleScaleBar extends StatelessWidget {
  final MapController mapCtrl;
  const _SimpleScaleBar({required this.mapCtrl});

  // metros por pixel según zoom y latitud (EPSG:3857)
  double _metersPerPixel(double zoom, double lat) {
    final latRad = lat * math.pi / 180.0;
    return 156543.03392 * math.cos(latRad) / math.pow(2.0, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final cam = mapCtrl.camera;
    final mpp = _metersPerPixel(cam.zoom, cam.center.latitude);

    // Elegimos una longitud de barra “bonita” (en px) y su etiqueta
    const targetPx = 100.0; // ancho visual de la barra
    final meters = targetPx * mpp;

    // Redondeo a 5/10/20/50/100… para que se vea prolijo
    final niceSteps = [1, 2, 5];
    double mag = math
        .pow(10, (math.log(meters) / math.ln10).floor())
        .toDouble();
    double nice = niceSteps.first * mag;
    for (final s in niceSteps) {
      final candidate = s * mag;
      if (candidate >= meters) {
        nice = candidate;
        break;
      }
    }

    final px = (nice / mpp).clamp(40.0, 160.0); // ancho final en px
    final label = (nice >= 1000)
        ? '${(nice / 1000).toStringAsFixed(nice >= 5000 ? 0 : 1)} km'
        : '${nice.toStringAsFixed(0)} m';

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.75),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // barra
              SizedBox(
                width: px,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.black26],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
