import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class RoutesResultScreen extends StatefulWidget {
  final double? destLat;
  final double? destLon;

  const RoutesResultScreen({super.key, this.destLat, this.destLon});

  @override
  State<RoutesResultScreen> createState() => _RoutesResultScreenState();
}

class _RoutesResultScreenState extends State<RoutesResultScreen> {
  final MapController _mapCtrl = MapController();

  // Origen/Destino (se setean en _initPositions)
  LatLng? _origin;
  LatLng? _destination;

  // Mock de forma/paradas para el “preview” de la línea (opcional)
  // (puedes mantenerlo si quieres ver tu trazo + paradas rojas)
  final List<LatLng> _shape = const [
    LatLng(-1.0280, -79.4685),
    LatLng(-1.0270, -79.4660),
    LatLng(-1.0253, -79.4625),
    LatLng(-1.0242, -79.4600),
    LatLng(-1.0226, -79.4575),
    LatLng(-1.0208, -79.4555),
    LatLng(-1.0186, -79.4540),
    LatLng(-1.0169, -79.4528),
  ];
  final List<LatLng> _stops = const [
    LatLng(-1.0278, -79.4676),
    LatLng(-1.0267, -79.4652),
    LatLng(-1.0250, -79.4617),
    LatLng(-1.0238, -79.4594),
    LatLng(-1.0222, -79.4571),
    LatLng(-1.0203, -79.4552),
    LatLng(-1.0182, -79.4538),
  ];

  // UI
  String origin = '15 de Noviembre, Venus del Río Quevedo';
  String destination = 'Estadio 7 de Octubre';
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _initPositions();
  }

  Future<void> _initPositions() async {
    // 1) DESTINO desde query
    if (widget.destLat != null && widget.destLon != null) {
      _destination = LatLng(widget.destLat!, widget.destLon!);
    }

    // 2) ORIGEN: tu ubicación (o fallback si no hay permiso)
    LatLng? myPos;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if ((perm == LocationPermission.always ||
              perm == LocationPermission.whileInUse) &&
          await Geolocator.isLocationServiceEnabled()) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        myPos = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}
    myPos ??= const LatLng(-1.0286, -79.4594); // fallback Quevedo

    _origin = myPos;

    // 3) (Opcional) Actualiza textos de cabecera si quieres con reverse geocoding luego.
    // por ahora deja los mock que ya pintan bien.

    if (!mounted) return;
    setState(() {});

    // Si el mapa ya está listo, ajusta vista
    _fitToRoute();
  }

  void _onMapReady() {
    _mapReady = true;
    _fitToRoute();
  }

  void _fitToRoute() {
    if (!_mapReady || _origin == null || _destination == null) return;
    final bounds = LatLngBounds.fromPoints([_origin!, _destination!]);
    _mapCtrl.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(
          28,
          160,
          28,
          260,
        ), // deja espacio a la tarjeta inferior/superior
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // ================= MAPA =================
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter:
                      _destination ??
                      _origin ??
                      const LatLng(-1.0286, -79.4594),
                  initialZoom: 14.5,
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
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.quevebus',
                    retinaMode: true,
                  ),

                  // Trazo ORIGEN -> DESTINO (azul) – nuestra “ruta” pedida
                  if (_origin != null && _destination != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_origin!, _destination!],
                          strokeWidth: 5,
                          color: cs.primary,
                        ),
                      ],
                    ),

                  // (Opcional) tu shape negro y paradas rojas de “preview”
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _shape,
                        strokeWidth: 6,
                        color: Colors.black87,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      for (final p in _stops)
                        Marker(
                          point: p,
                          width: 10,
                          height: 10,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      if (_origin != null)
                        Marker(
                          point: _origin!,
                          width: 42,
                          height: 42,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 30,
                          ),
                        ),
                      if (_destination != null)
                        Marker(
                          point: _destination!,
                          width: 42,
                          height: 42,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.green,
                            size: 36,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ===== BOTÓN BACK
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 1,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_rounded, size: 22),
                  ),
                ),
              ),
            ),

            // ===== CARD ORIGEN/DESTINO SUPERIOR
            Positioned(
              top: 12,
              left: 56,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _odRow(
                      icon: Icons.location_on,
                      label: 'Origen',
                      value: origin,
                    ),
                    const SizedBox(height: 8),
                    _odRow(
                      icon: Icons.place,
                      label: 'Destino',
                      value: destination,
                    ),
                  ],
                ),
              ),
            ),

            // ===== PANEL INFERIOR: resultado principal + lista (igual que antes)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Item destacado
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Icon(Icons.directions_transit_filled),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Expanded(
                                          child: Text(
                                            '1:52 p.m. — 2:13 p.m.',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '21 min',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: const [
                                        Icon(Icons.directions_walk, size: 16),
                                        Text('›'),
                                        Icon(Icons.directions_bus, size: 16),
                                        Text('›'),
                                        Icon(Icons.directions_walk, size: 16),
                                        SizedBox(width: 8),
                                        _LinePill(
                                          text: 'Línea 1',
                                          color: Color(0xFFFFA000),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      '1:56 p.m.  de La venus Calle 1 de mayo',
                                      style: TextStyle(color: Colors.black87),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: const [
                                        Icon(
                                          Icons.timer,
                                          size: 15,
                                          color: Colors.black54,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '10 min',
                                          style: TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Text(
                                          'cada 7 min',
                                          style: TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: () =>
                                            context.push('/itinerary/1'),
                                        child: const Text('Detalles'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    _altItem(
                      horario: '1:50 p.m. — 2:16 p.m.',
                      minutos: 26,
                      lineas: const [
                        _LinePill(text: 'Línea 8', color: Color(0xFF0E3A66)),
                      ],
                      onTap: () => context.push('/itinerary/2'),
                    ),
                    _altItem(
                      horario: '1:52 p.m. — 2:17 p.m.',
                      minutos: 25,
                      lineas: const [
                        _LinePill(text: 'Línea 13', color: Color(0xFF26A269)),
                      ],
                      onTap: () => context.push('/itinerary/3'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Helpers UI ----

  Widget _odRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 6),
        const Icon(Icons.edit, size: 18, color: Colors.black45),
      ],
    );
  }

  Widget _altItem({
    required String horario,
    required int minutos,
    required List<Widget> lineas,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: const Icon(Icons.directions_transit),
      title: Text(horario, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: const [
          Icon(Icons.directions_walk, size: 16),
          Text('›'),
          Icon(Icons.directions_bus, size: 16),
          Text('›'),
          Icon(Icons.directions_walk, size: 16),
        ],
      ),
      trailing: Text(
        '$minutos min',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _LinePill extends StatelessWidget {
  final String text;
  final Color color;
  const _LinePill({required this.text, required this.color});

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
