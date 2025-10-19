import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

class SelectOnMapScreen extends StatefulWidget {
  const SelectOnMapScreen({super.key});

  @override
  State<SelectOnMapScreen> createState() => _SelectOnMapScreenState();
}

class _SelectOnMapScreenState extends State<SelectOnMapScreen> {
  final MapController _mapCtrl = MapController();

  static const LatLng _fallbackCenter = LatLng(-1.0286, -79.4594);
  static const double _initialZoom = 16;

  LatLng _center = _fallbackCenter; // centro/pin actual
  String _address = 'Buscando dirección…';
  bool _mapReady = false;
  bool _loading = true;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initPosition();
  }

  Future<void> _initPosition() async {
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
        _center = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {
      // usa fallback
    }

    if (!mounted) return;
    setState(() => _loading = false);

    // cuando el mapa esté listo moveremos y haremos reverse-geocode
  }

  // Llama geocoding con debounce para no saturar al mover el mapa
  void _reverseGeocodeDebounced(LatLng p) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final placemarks = await gc.placemarkFromCoordinates(
          p.latitude,
          p.longitude,
        );
        if (!mounted) return;
        if (placemarks.isNotEmpty) {
          final m = placemarks.first;
          final parts = [
            m.name,
            m.street,
            m.subLocality,
            m.locality,
          ].where((e) => (e ?? '').toString().trim().isNotEmpty).toList();
          final txt = parts.join(', ');
          setState(
            () => _address = txt.isEmpty
                ? '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}'
                : txt,
          );
        } else {
          setState(
            () => _address =
                '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
          );
        }
      } catch (_) {
        if (!mounted) return;
        setState(
          () => _address =
              '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
        );
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    // Mueve al centro inicial conocido y calcula dirección
    _mapCtrl.move(_center, _initialZoom);
    _reverseGeocodeDebounced(_center);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // ====== MAPA ======
            Positioned.fill(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                      mapController: _mapCtrl,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _initialZoom,
                        onMapReady: _onMapReady,
                        // Cada evento de mapa actualiza el centro y el banner
                        onMapEvent: (evt) {
                          if (!_mapReady) return;
                          // el "pin" va en el centro del mapa
                          final newCenter = _mapCtrl.center;
                          setState(() => _center = newCenter);

                          // cuando termina el gesto/animación pedimos dirección
                          if (evt is MapEventMoveEnd ||
                              evt is MapEventFlingAnimationEnd) {
                            _reverseGeocodeDebounced(newCenter);
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
                        // Marcador en el centro (tu pin “se mueve con el mapa”)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _center,
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

            // ====== BOTÓN BACK CÍRCULO BLANCO ======
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

            // ====== BANNER SUPERIOR: DIRECCIÓN SELECCIONADA ======
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
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dirección seleccionada:',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ====== BOTÓN INFERIOR “Seleccionar dirección” ======
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  // ...
                  onPressed: () {
                    // Navega a resultados pasando el destino seleccionado
                    final lat = _center.latitude.toStringAsFixed(6);
                    final lon = _center.longitude.toStringAsFixed(6);
                    context.go('/results?lat=$lat&lon=$lon');
                  },

                  child: const Text(
                    'Seleccionar dirección',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
