import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ItineraryDetailScreen extends StatefulWidget {
  final String itineraryId;
  const ItineraryDetailScreen({super.key, required this.itineraryId});

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen>
    with TickerProviderStateMixin {
  final MapController _mapCtrl = MapController();

  // ---------- MOCK DE COORDENADAS ----------
  // 3 segmentos: walk1 -> bus -> walk2
  final List<LatLng> walk1 = const [
    LatLng(-1.0269, -79.4668),
    LatLng(-1.0263, -79.4658),
    LatLng(-1.0256, -79.4645),
    LatLng(-1.0250, -79.4635),
  ];
  final List<LatLng> bus = const [
    LatLng(-1.0250, -79.4635),
    LatLng(-1.0242, -79.4620),
    LatLng(-1.0232, -79.4602),
    LatLng(-1.0222, -79.4590),
    LatLng(-1.0212, -79.4579),
    LatLng(-1.0202, -79.4568),
    LatLng(-1.0192, -79.4558),
  ];
  final List<LatLng> walk2 = const [
    LatLng(-1.0192, -79.4558),
    LatLng(-1.0187, -79.4550),
    LatLng(-1.0182, -79.4543),
  ];

  late final List<LatLng> wholeRoute;

  // Animación del “usuario”
  Timer? _timer;
  int _idx = 0;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    wholeRoute = [...walk1, ...bus, ...walk2];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    // Enfoca toda la ruta
    final bounds = LatLngBounds.fromPoints(wholeRoute);
    _mapCtrl.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      ),
    );
    // Inicia una animación simple que avanza el "usuario"
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) return;
      setState(() {
        _idx = (_idx + 1) % wholeRoute.length;
        // "seguir" al usuario moviendo suavemente el centro (prototipo)
        _mapCtrl.move(wholeRoute[_idx], _mapCtrl.camera.zoom);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del itinerario')),
      body: Column(
        children: [
          // ================= MAPA =================
          SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: wholeRoute.first,
                initialZoom: 15,
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

                // Caminata 1 (punteada azul: simulada con pequeños puntos)
                MarkerLayer(markers: _dotted(walk1, color: Colors.blue)),
                // Bus (línea naranja sólida)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: bus,
                      strokeWidth: 6,
                      color: const Color(0xFFFF8F00),
                    ),
                  ],
                ),
                // Caminata 2 (punteada azul)
                MarkerLayer(markers: _dotted(walk2, color: Colors.blue)),

                // Usuario “siguiendo la ruta”
                MarkerLayer(
                  markers: [
                    Marker(
                      point: wholeRoute[_idx],
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.person_pin_circle,
                        size: 36,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ================= TIMELINE =================
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: const [
                _TimelineItem(
                  time: '1:52 p.m.',
                  title: 'La parroquia venus',
                  subtitle: 'Calle 1 de mayo y miguel',
                  type: StepType.start,
                ),
                _TimelineSpacerWalk(),
                _TimelineItem(
                  time: '',
                  title: 'A pie',
                  subtitle: 'Alrededor de 4 min, 270 metros',
                  type: StepType.walk,
                ),
                _DividerThin(),
                _TimelineItem(
                  time: '1:56 p.m.',
                  title: 'Parada 2 Venus',
                  subtitle: '',
                  type: StepType.stop,
                ),
                _TimelineSpacerBus(),
                _TimelineItem(
                  time: '',
                  title: 'Línea 8 · Paseo SShopping Quevedo',
                  subtitle: '11 min (16 paradas)',
                  type: StepType.bus,
                  pillText: 'Línea 8',
                ),
                _DividerThin(),
                _TimelineItem(
                  time: '2:07 p.m.',
                  title: 'Variante 1 Quevedo',
                  subtitle: '',
                  type: StepType.stop,
                ),
                _TimelineSpacerWalk(),
                _TimelineItem(
                  time: '',
                  title: 'A pie',
                  subtitle: 'Alrededor de 6 min, 350 metros',
                  type: StepType.walk,
                ),
                _DividerThin(),
                _TimelineItem(
                  time: '2:13 p.m.',
                  title: 'Estadio 7 de Octubre',
                  subtitle: 'Calle xxx Quevedo',
                  type: StepType.end,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Genera puntos “punteados” para las secciones de caminata
  List<Marker> _dotted(List<LatLng> line, {required Color color}) {
    // Interpola puntos cada ~25–35 metros aprox (mock simple)
    final distance = const Distance();
    final markers = <Marker>[];
    for (var i = 0; i < line.length - 1; i++) {
      final a = line[i];
      final b = line[i + 1];
      final d = distance(a, b);
      final steps = (d / 30).clamp(1, 10).round();
      for (var s = 0; s <= steps; s++) {
        final t = s / steps;
        final lat = a.latitude + (b.latitude - a.latitude) * t;
        final lon = a.longitude + (b.longitude - a.longitude) * t;
        markers.add(
          Marker(
            point: LatLng(lat, lon),
            width: 6,
            height: 6,
            child: Container(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        );
      }
    }
    return markers;
  }
}

// ======================= TIMELINE WIDGETS =======================

enum StepType { start, walk, stop, bus, end }

class _TimelineItem extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final StepType type;
  final String? pillText;

  const _TimelineItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.type,
    this.pillText,
  });

  @override
  Widget build(BuildContext context) {
    // Colores por tipo
    const blue = Color(0xFF1E88E5);
    const orange = Color(0xFFFF8F00);
    final color = switch (type) {
      StepType.walk => blue,
      StepType.bus => orange,
      _ => Colors.black54,
    };

    final icon = switch (type) {
      StepType.walk => Icons.directions_walk_rounded,
      StepType.bus => Icons.directions_bus_rounded,
      StepType.start => Icons.radio_button_unchecked,
      StepType.stop => Icons.radio_button_unchecked,
      StepType.end => Icons.radio_button_unchecked,
    };

    // Línea vertical lateral y punto
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(time, style: const TextStyle(color: Colors.black87)),
        ),
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54, width: 2),
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 3,
                height: 42,
                decoration: BoxDecoration(
                  color: type == StepType.bus ? orange : blue.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (type == StepType.bus && pillText != null) ...[
                    const SizedBox(width: 8),
                    _LinePill(text: pillText!, color: orange),
                  ],
                ],
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineSpacerWalk extends StatelessWidget {
  const _TimelineSpacerWalk({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SizedBox(width: 64),
        SizedBox(width: 24, child: _SpacerLine(color: Color(0xFF1E88E5))),
        SizedBox(width: 8),
        Expanded(child: SizedBox(height: 6)),
      ],
    );
  }
}

class _TimelineSpacerBus extends StatelessWidget {
  const _TimelineSpacerBus({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SizedBox(width: 64),
        SizedBox(width: 24, child: _SpacerLine(color: Color(0xFFFF8F00))),
        SizedBox(width: 8),
        Expanded(child: SizedBox(height: 6)),
      ],
    );
  }
}

class _SpacerLine extends StatelessWidget {
  final Color color;
  const _SpacerLine({required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      width: 3,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _DividerThin extends StatelessWidget {
  const _DividerThin({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(height: 1),
    );
  }
}

class _LinePill extends StatelessWidget {
  final String text;
  final Color color;
  const _LinePill({required this.text, required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
