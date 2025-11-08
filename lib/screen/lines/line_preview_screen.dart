// lib/screen/lines/line_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

import 'package:quevebus/core/routing/models.dart'; // BusLine
import 'package:quevebus/core/services/street_router.dart'; // ⬅️ nuevo
import 'package:quevebus/core/services/lines_repository.dart'; // ✅ Aquí está BusLine

class LinePreviewScreen extends StatefulWidget {
  final BusLine line;
  const LinePreviewScreen({super.key, required this.line});

  @override
  State<LinePreviewScreen> createState() => _LinePreviewScreenState();
}

class _LinePreviewScreenState extends State<LinePreviewScreen> {
  final MapController _mapCtrl = MapController();
  bool _mapReady = false;

  List<LatLng> _allPoints = const [];
  List<LatLng> _stops = const [];
  List<LatLng> _streetPolyline = const []; // ⬅️ ruta siguiendo calles
  bool _streetLoading = true;
  bool _streetFailed = false;

  @override
  void initState() {
    super.initState();
    _prepareData();
    _buildStreetPolyline(); // ⬅️ calcula la ruta por calles
  }

  void _prepareData() {
    final line = widget.line;

    // 1) unir todos los puntos de todos los segmentos (tu polilínea base)
    final pts = <LatLng>[];
    for (final seg in line.segments) {
      pts.addAll(seg);
    }
    _allPoints = pts;

    // 2) Paradas = todos los puntos (en orden). Start/End se distinguen con icono
    _stops = pts;
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
  }

  void _onMapReady() {
    _mapReady = true;
    _fitBounds();
  }

  void _fitBounds() {
    if (!_mapReady) return;
    final pts = _streetPolyline.isNotEmpty ? _streetPolyline : _allPoints;
    if (pts.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(pts);
    _mapCtrl.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(28, 140, 28, 60),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final title = (line.name?.isNotEmpty == true)
        ? line.name!
        : 'Línea ${line.id}';

    final totalPts = _allPoints.length;
    final nStops = _stops.length;
    final nSegs = line.segments.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Vista de $title'),
        actions: [
          IconButton(
            tooltip: 'Reencuadrar',
            onPressed: _fitBounds,
            icon: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(
          initialCenter: _allPoints.isNotEmpty
              ? _allPoints.first
              : const LatLng(-1.0286, -79.4594),
          initialZoom: 14.0,
          onMapReady: _onMapReady,
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

          // 1) Polilínea por calles (si existe) en azul oscuro
          if (_streetPolyline.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _streetPolyline,
                  strokeWidth: 6,
                  color: const Color(0xFF1565C0),
                ),
              ],
            ),

          // 2) Fallback: tu segmento original (recto) si OSRM falló
          if (_streetPolyline.isEmpty)
            PolylineLayer(
              polylines: [
                for (final seg in line.segments)
                  Polyline(points: seg, strokeWidth: 6, color: Colors.blueGrey),
              ],
            ),

          // 3) Paradas (todas) en rojo; inicio/fin distintos
          MarkerLayer(
            markers: [
              for (int i = 0; i < _stops.length; i++)
                Marker(
                  point: _stops[i],
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  child: _buildStopDot(i, _stops.length),
                ),
            ],
          ),

          // 4) Estado de ruteo
          if (_streetLoading)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Calculando ruta por calles...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_streetFailed && !_streetLoading)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'No se pudo rutear por calles (usando rectas).',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Row(
          children: [
            const Icon(Icons.directions_bus_filled, color: Colors.black87),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Segmentos: $nSegs  •  Puntos: $totalPts  •  Paradas: $nStops',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Punto normal (rojo), inicio (verde), fin (negro) con borde blanco.
  Widget _buildStopDot(int idx, int total) {
    if (idx == 0) {
      return _dot(color: Colors.green.shade600);
    } else if (idx == total - 1) {
      return _dot(color: Colors.black87);
    }
    return _dot(color: Colors.red.shade600);
  }

  Widget _dot({required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
