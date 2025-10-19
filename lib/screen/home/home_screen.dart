import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapCtrl = MapController();

  LatLng? _myLatLng; // tu ubicación
  bool _loading = true;
  bool _mapReady = false;

  // Centro por defecto (Quevedo, EC aprox) por si no hay permiso/GPS
  static const LatLng _fallbackCenter = LatLng(-1.0286, -79.4594);
  static const double _initialZoom = 14.0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        if (await Geolocator.isLocationServiceEnabled()) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          _myLatLng = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {
      // ignora: usaremos fallback
    }

    _myLatLng ??= _fallbackCenter;

    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _recenter() {
    if (_myLatLng != null && _mapReady) {
      _mapCtrl.move(_myLatLng!, _initialZoom);
    }
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppSideDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            // ======= MAPA REAL =======
            Positioned.fill(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                      mapController: _mapCtrl,
                      options: MapOptions(
                        initialCenter: _myLatLng ?? _fallbackCenter,
                        initialZoom: _initialZoom,
                        onMapReady: () {
                          _mapReady = true; // listo el mapa
                          if (_myLatLng != null) {
                            _mapCtrl.move(_myLatLng!, _initialZoom); // ahora sí
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
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.quevebus',
                          retinaMode: true,
                        ),
                        MarkerLayer(
                          markers: [
                            if (_myLatLng != null)
                              Marker(
                                point: _myLatLng!,
                                width: 42,
                                height: 42,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  size: 42,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),

            // ======= BOTONES SUPERIORES (iconos default) =======
            Positioned(
              left: 12,
              top: 12,
              child: _roundButton(cs.primary, Icons.menu, _openDrawer),
            ),
            Positioned(
              right: 76,
              top: 12,
              child: _roundButton(cs.primary, Icons.help_outline, () {
                // Prototipo: aquí podrías abrir /menu/support si quieres
                // context.go('/menu/support');
              }),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: _roundButton(
                cs.primary,
                Icons.near_me_rounded,
                _recenter, // recentra el mapa
              ),
            ),

            // ======= CTA INFERIOR =======
            Positioned(
              left: 12,
              right: 12,
              bottom: 18,
              child: GestureDetector(
                onTap: () => context.push('/search'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDEFF2),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        spreadRadius: -2,
                      ),
                    ],
                    border: Border.all(color: Colors.black12, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26, width: 2),
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '¿Dónde vamos hoy?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Botón redondo azul con icono blanco
  Widget _roundButton(Color bg, IconData icon, VoidCallback onTap) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
