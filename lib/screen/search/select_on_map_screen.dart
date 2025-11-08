import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:quevebus/core/services/recents_service.dart';

// ================= Config geocoder =================
enum GeoProvider { geoapify, nominatim }

// Pega aquí tu API key (o déjala vacía para usar Nominatim)
const String GEOAPIFY_API_KEY =
    '6cf8aa5f5d2e45f0bac21790ca90c6ae'; // <- tu key o vacío

// NO const aquí: evalúalo en runtime
final GeoProvider GEO_PROVIDER = GEOAPIFY_API_KEY.isNotEmpty
    ? GeoProvider.geoapify
    : GeoProvider.nominatim;
// ===================================================

class SelectOnMapScreen extends StatefulWidget {
  const SelectOnMapScreen({super.key});

  @override
  State<SelectOnMapScreen> createState() => _SelectOnMapScreenState();
}

class _SelectOnMapScreenState extends State<SelectOnMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapCtrl = MapController();

  static const LatLng _fallbackCenter = LatLng(-1.0286, -79.4594);
  static const double _initialZoom = 16;

  LatLng _center = _fallbackCenter; // centro/pin actual
  String _address = 'Buscando dirección…';
  bool _mapReady = false;
  bool _loading = true;
  bool _resolvingAddr = false;

  Timer? _debounce;

  // extras recibidos
  double? _initialLat;
  double? _initialLon;
  String? _initialLabel;
  bool _readExtras = false; // evita leer varias veces

  // Animación del pin (pulso)
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);
  late final Animation<double> _pulse = Tween<double>(
    begin: 0.92,
    end: 1.08,
  ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readExtras) return;
    _readExtras = true;

    final state = GoRouterState.of(context);
    final extra = state.extra;
    if (extra is Map) {
      _initialLat = (extra['initialLat'] as num?)?.toDouble();
      _initialLon = (extra['initialLon'] as num?)?.toDouble();
      _initialLabel = extra['initialLabel'] as String?;
    }

    _initPosition(); // ahora sí, con extras leídos
  }

  Future<void> _initPosition() async {
    if (_initialLat != null && _initialLon != null) {
      _center = LatLng(_initialLat!, _initialLon!);
      _address = _initialLabel ?? _address;
      if (mounted) setState(() => _loading = false);
      return;
    }

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
    } catch (_) {}

    if (!mounted) return;
    setState(() => _loading = false);
  }

  // --------- Reverse geocoding con Nominatim (mejor etiqueta de calle) ----------
  Future<void> _reverseGeocode(LatLng p) async {
    if (GEO_PROVIDER == GeoProvider.geoapify) {
      await _reverseGeocodeGeoapify(p);
    } else {
      await _reverseGeocodeNominatim(p);
    }
  }

  Future<void> _reverseGeocodeGeoapify(LatLng p) async {
    setState(() {
      _resolvingAddr = true;
      _address = 'Buscando dirección…';
    });

    final uri = Uri.parse('https://api.geoapify.com/v1/geocode/reverse')
        .replace(
          queryParameters: {
            'lat': '${p.latitude}',
            'lon': '${p.longitude}',
            'lang': 'es',
            'format': 'json',
            'apiKey': GEOAPIFY_API_KEY,
          },
        );

    try {
      final resp = await http.get(
        uri,
        headers: const {
          'User-Agent': 'QueveBus/0.1 (contacto: dev@quevebus.app)',
          'Accept': 'application/json',
        },
      );
      if (resp.statusCode != 200) return _setAddrFallback(p);

      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (jsonMap['results'] as List?) ?? const [];
      if (results.isEmpty) return _setAddrFallback(p);

      final r = results.first as Map<String, dynamic>;

      // Partes amigables
      final name = (r['name'] ?? '').toString().trim();
      final street = (r['street'] ?? '').toString().trim();
      final house = (r['housenumber'] ?? '').toString().trim();
      final suburb = (r['suburb'] ?? r['neighbourhood'] ?? '')
          .toString()
          .trim();
      final city = (r['city'] ?? r['town'] ?? r['village'] ?? '')
          .toString()
          .trim();

      final primary = [
        if (name.isNotEmpty) name else null,
        [street, house].where((e) => e.isNotEmpty).join(' ').trim().isNotEmpty
            ? [street, house].where((e) => e.isNotEmpty).join(' ').trim()
            : null,
      ].whereType<String>().join(' • ');

      final secondary = [suburb, city].where((e) => e.isNotEmpty).join(', ');

      if (!mounted) return;
      setState(() {
        _address = [
          if (primary.isNotEmpty) primary else (r['formatted'] ?? ''),
          if (secondary.isNotEmpty) secondary,
        ].where((e) => e.toString().trim().isNotEmpty).join(' — ');
        _resolvingAddr = false;
      });
    } catch (_) {
      _setAddrFallback(p);
    }
  }

  Future<void> _reverseGeocodeNominatim(LatLng p) async {
    setState(() {
      _resolvingAddr = true;
      _address = 'Buscando dirección…';
    });

    final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse')
        .replace(
          queryParameters: {
            'lat': '${p.latitude}',
            'lon': '${p.longitude}',
            'format': 'jsonv2',
            'addressdetails': '1',
            'accept-language': 'es',
            'zoom': '18',
          },
        );

    try {
      final resp = await http.get(
        uri,
        headers: const {
          'User-Agent': 'QueveBus/0.1 (contacto: dev@quevebus.app)',
          'Accept': 'application/json',
        },
      );
      if (resp.statusCode != 200) return _setAddrFallback(p);

      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      final addr = (jsonMap['address'] ?? {}) as Map<String, dynamic>;

      final name = (jsonMap['name'] ?? '').toString().trim();
      final road = (addr['road'] ?? addr['pedestrian'] ?? '').toString();
      final house = (addr['house_number'] ?? '').toString();
      final suburb = (addr['suburb'] ?? addr['neighbourhood'] ?? '').toString();
      final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? '')
          .toString();

      final primary = [
        if (name.isNotEmpty) name else null,
        [road, house]
                .where((e) => e.toString().trim().isNotEmpty)
                .join(' ')
                .trim()
                .isNotEmpty
            ? [
                road,
                house,
              ].where((e) => e.toString().trim().isNotEmpty).join(' ').trim()
            : null,
      ].whereType<String>().join(' • ');

      final secondary = [
        suburb,
        city,
      ].where((e) => e.trim().isNotEmpty).join(', ');

      if (!mounted) return;
      setState(() {
        _address = [
          if (primary.isNotEmpty) primary else (jsonMap['display_name'] ?? ''),
          if (secondary.isNotEmpty) secondary,
        ].where((e) => e.toString().trim().isNotEmpty).join(' — ');
        _resolvingAddr = false;
      });
    } catch (_) {
      _setAddrFallback(p);
    }
  }

  void _setAddrFallback(LatLng p) {
    if (!mounted) return;
    setState(() {
      _address =
          '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
      _resolvingAddr = false;
    });
  }

  // Debounce para no saturar mientras se arrastra el mapa
  void _reverseGeocodeDebounced(LatLng p) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _reverseGeocode(p);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    _mapCtrl.move(_center, _initialZoom);
    if (_initialLabel == null) {
      _reverseGeocodeDebounced(_center);
    }
  }

  Future<void> _recenterToMyLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final p = LatLng(pos.latitude, pos.longitude);
      _mapCtrl.move(p, _initialZoom);
      setState(() {
        _center = p;
        _initialLabel = null; // forzamos a resolver con reverse
      });
      _reverseGeocodeDebounced(p);
    } catch (_) {}
  }

  Future<void> _confirmSelection() async {
    final lat = _center.latitude;
    final lon = _center.longitude;

    await RecentsService.add(
      RecentDestination(
        label: _initialLabel ?? _address,
        lat: lat,
        lon: lon,
        at: DateTime.now(),
      ),
    );

    final slat = lat.toStringAsFixed(6);
    final slon = lon.toStringAsFixed(6);
    if (!mounted) return;
    context.go('/results?lat=$slat&lon=$slon');
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
                        onMapEvent: (evt) {
                          if (!_mapReady) return;
                          final newCenter = _mapCtrl.center;
                          setState(() => _center = newCenter);

                          if (evt is MapEventMoveEnd ||
                              evt is MapEventFlingAnimationEnd) {
                            if (_initialLabel != null) {
                              _initialLabel =
                                  null; // al primer movimiento, resetea
                            }
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
                        // Marcador en el centro (pin animado)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _center,
                              width: 50,
                              height: 64,
                              alignment: Alignment.topCenter,
                              child: ScaleTransition(
                                scale: _pulse,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded, // gota
                                      size: 44,
                                      color: Color(0xFFE53935), // rojo elegante
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      width: 24,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.black12,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ],
                                ),
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
              child: _roundBtn(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
              ),
            ),

            // ====== BOTÓN RECENTRAR ======
            Positioned(
              top: 12,
              right: 12,
              child: _roundBtn(
                icon: Icons.my_location_rounded,
                onTap: _recenterToMyLocation,
              ),
            ),

            // ====== BANNER SUPERIOR: DIRECCIÓN SELECCIONADA ======
            Positioned(
              top: 12,
              left: 56,
              right: 56,
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
                          Row(
                            children: [
                              const Text(
                                'Dirección seleccionada:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              if (_resolvingAddr) ...[
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _initialLabel ?? _address,
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
                  onPressed: _confirmSelection,
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

  Widget _roundBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: Colors.black87),
        ),
      ),
    );
  }
}
