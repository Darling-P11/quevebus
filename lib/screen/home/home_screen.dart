import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapCtrl = MapController();

  LatLng? _myLatLng; // tu ubicación
  bool _loading = true;
  bool _mapReady = false;

  // Centro por defecto (Quevedo, EC aprox) por si no hay permiso/GPS
  static const LatLng _fallbackCenter = LatLng(-1.0286, -79.4594);
  static const double _initialZoom = 16.0; // más cerca

  // Animaciones
  late final AnimationController _flyCtrl; // animación cámara
  late final AnimationController _rippleCtrl; // ripple del pin
  late final AnimationController _gpsBtnCtrl; // bounce botón GPS

  // Stream de ubicación
  StreamSubscription<Position>? _posSub;
  bool _isFollowingCamera = true; // si true, la cámara acompaña al moverse

  @override
  void initState() {
    super.initState();
    _flyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _gpsBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _initLocation();
  }

  @override
  void dispose() {
    _flyCtrl.dispose();
    _rippleCtrl.dispose();
    _gpsBtnCtrl.dispose();
    _posSub?.cancel();
    super.dispose();
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

          // Suscripción al movimiento — actualiza el pin automáticamente.
          final settings = const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5, // en metros
          );
          _posSub?.cancel();
          _posSub = Geolocator.getPositionStream(locationSettings: settings)
              .listen((p) {
                final next = LatLng(p.latitude, p.longitude);
                setState(() => _myLatLng = next);
                if (_mapReady && _isFollowingCamera) {
                  _flyTo(next, _mapCtrl.camera.zoom);
                }
              });
        }
      }
    } catch (_) {
      // ignora: usaremos fallback
    }

    _myLatLng ??= _fallbackCenter;

    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// Interpola entre centro/zoom actuales y el objetivo con easing y mueve el mapa.
  Future<void> _flyTo(LatLng target, double targetZoom) async {
    if (!_mapReady) return;

    final camera = _mapCtrl.camera;
    final start = camera.center;
    final startZoom = camera.zoom;

    final curve = CurvedAnimation(parent: _flyCtrl, curve: Curves.easeOutCubic);

    void tick() {
      final t = curve.value;
      final lat = start.latitude + (target.latitude - start.latitude) * t;
      final lon = start.longitude + (target.longitude - start.longitude) * t;
      final z = startZoom + (targetZoom - startZoom) * t;
      _mapCtrl.move(LatLng(lat, lon), z);
    }

    late VoidCallback listener;
    listener = () {
      tick();
      if (_flyCtrl.isCompleted) _flyCtrl.removeListener(listener);
    };

    _flyCtrl
      ..reset()
      ..addListener(listener)
      ..forward();
  }

  Future<void> _flyToMyLocation() async {
    if (_myLatLng == null) return;
    HapticFeedback.selectionClick();
    await _gpsBtnCtrl.forward();
    await _gpsBtnCtrl.reverse();
    await _flyTo(_myLatLng!, _initialZoom);
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
            // ======= MAPA =======
            Positioned.fill(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                      mapController: _mapCtrl,
                      options: MapOptions(
                        initialCenter: _myLatLng ?? _fallbackCenter,
                        initialZoom: _initialZoom,
                        onMapReady: () {
                          _mapReady = true;
                          if (_myLatLng != null) {
                            _flyTo(
                              _myLatLng!,
                              _initialZoom,
                            ); // animado al iniciar
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
                                width: 80,
                                height: 80,
                                alignment: Alignment.center,
                                child: _AnimatedUserPin(
                                  color: const Color(0xFF1565C0),
                                  controller: _rippleCtrl,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),

            // ======= BOTONES SUPERIORES (restaurados) =======
            Positioned(
              left: 12,
              top: 12,
              child: _roundButton(cs.primary, Icons.menu, _openDrawer),
            ),
            Positioned(
              right: 76,
              top: 12,
              child: _roundButton(cs.primary, Icons.directions_bus, () {
                context.go('/menu/lines-test');
              }),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.12).animate(
                  CurvedAnimation(
                    parent: _gpsBtnCtrl,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: _roundButton(
                  cs.primary,
                  Icons.near_me_rounded,
                  _flyToMyLocation, // animado
                  tooltip: _isFollowingCamera
                      ? 'Centrar (seguimiento ON)'
                      : 'Centrar',
                  onLongPress: () {
                    // toggle opcional de seguimiento de cámara
                    setState(() => _isFollowingCamera = !_isFollowingCamera);
                    final msg = _isFollowingCamera
                        ? 'Seguimiento de cámara activado'
                        : 'Seguimiento de cámara desactivado';
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
                  },
                ),
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

  // Botón redondo azul con icono blanco (restaurado)
  Widget _roundButton(
    Color bg,
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
    VoidCallback? onLongPress,
  }) {
    final child = Padding(
      padding: const EdgeInsets.all(14),
      child: Icon(icon, color: Colors.white, size: 22),
    );

    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 2,
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          customBorder: const CircleBorder(),
          child: child,
        ),
      ),
    );
  }
}

/// Pin de usuario con “ripple” y aro blanco (sin usar ícono por defecto)
class _AnimatedUserPin extends StatelessWidget {
  final Color color;
  final AnimationController controller;
  const _AnimatedUserPin({required this.color, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value; // 0..1
        final rippleScale = 1.0 + t * 1.4;
        final rippleOpacity = (1.0 - t).clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Ripple
            Opacity(
              opacity: rippleOpacity,
              child: Transform.scale(
                scale: rippleScale,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.18),
                  ),
                ),
              ),
            ),

            // Sombra suave
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

            // Aro blanco + centro azul
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
