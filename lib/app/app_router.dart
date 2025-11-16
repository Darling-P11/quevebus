import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// ⬇️ Cambiado de features/* a screen/*
import 'package:quevebus/screen/splash/splash_screen.dart';
import 'package:quevebus/screen/permissions/permissions_screen.dart';
import 'package:quevebus/screen/home/home_screen.dart';
import 'package:quevebus/screen/search/search_screen.dart';
import 'package:quevebus/screen/search/select_on_map_screen.dart';
import 'package:quevebus/screen/results/routes_result_screen.dart';
import 'package:quevebus/screen/itinerary/itinerary_detail_screen.dart';
import 'package:quevebus/screen/menu/permissions_settings_screen.dart';
import 'package:quevebus/screen/menu/invite_friends_screen.dart';
import 'package:quevebus/screen/menu/support_screen.dart';
import 'package:quevebus/screen/menu/about_screen.dart';

// ⬇️ Servicio para chequear el permiso real del SO
import 'package:quevebus/core/services/permissions_service.dart';
import 'package:quevebus/screen/lines/lines_test_screen.dart';
import 'package:quevebus/screen/lines/line_preview_screen.dart';
import 'package:quevebus/core/services/lines_repository.dart'
    show BusLine; // para el cast del extra
// imports nuevos
import 'package:quevebus/core/services/lines_repository.dart'; // para BusLine

import 'package:quevebus/core/services/itinerary_engine.dart';
import 'package:quevebus/screen/itinerary/TravelScreen.dart';

GoRouter buildRouter() {
  return GoRouter(
    // Iniciamos en "/" (SplashScreen). El redirect decidirá a dónde ir.
    initialLocation: '/',
    routes: [
      // SPLASH: solo pantalla visual; la redirección global decide el flujo.
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // Pantalla explicativa/solicitud de permisos
      GoRoute(
        path: '/permissions',
        name: 'permissions',
        builder: (_, __) => const PermissionsScreen(),
      ),

      // Home (mapa)
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (_, __) => const HomeScreen(),
      ),

      // Búsqueda OD
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (_, __) => const SearchScreen(),
      ),

      // Seleccionar en mapa
      GoRoute(
        path: '/select-on-map',
        name: 'selectOnMap',
        builder: (_, __) => const SelectOnMapScreen(),
      ),

      // Resultados (acepta lat/lon por query params)
      //GoRoute(
      // path: '/results',
      // name: 'results',
      // builder: (context, state) {
      //   final qp = state.uri.queryParameters;
      //   final lat = double.tryParse(qp['lat'] ?? '');
      //  final lon = double.tryParse(qp['lon'] ?? '');
      //return RoutesResultScreen(destLat: lat, destLon: lon);
      // },
      //),

      // Itinerario (detalle)
      GoRoute(
        path: '/itinerary/:id',
        name: 'itineraryDetail',
        builder: (_, st) =>
            ItineraryDetailScreen(itineraryId: st.pathParameters['id'] ?? '1'),
      ),

      GoRoute(
        path: '/travel',
        name: 'travel',
        builder: (context, state) {
          final option = state.extra as ItineraryOption;
          return TravelScreen(option: option);
        },
      ),

      // Menú: Ajustes de permisos
      GoRoute(
        path: '/menu/permissions',
        name: 'menuPermissions',
        builder: (_, __) => const PermissionsSettingsScreen(),
      ),

      // Menú: Invitar amigos
      GoRoute(
        path: '/menu/invite',
        name: 'menuInvite',
        builder: (_, __) => const InviteFriendsScreen(),
      ),

      // Menú: Soporte
      GoRoute(
        path: '/menu/support',
        name: 'menuSupport',
        builder: (_, __) => const SupportScreen(),
      ),

      // Menú: Acerca de
      GoRoute(
        path: '/menu/about',
        name: 'menuAbout',
        builder: (_, __) => const AboutScreen(),
      ),

      // Test de líneas
      GoRoute(
        path: '/menu/lines-test',
        name: 'linesTest',
        builder: (_, __) => const LinesTestScreen(),
      ),

      // Preview de una línea
      GoRoute(
        path: '/line-preview',
        name: 'linePreview',
        builder: (ctx, st) {
          final extra = st.extra;
          if (extra is BusLine) return LinePreviewScreen(line: extra);
          return const Scaffold(body: Center(child: Text('Línea no recibida')));
        },
      ),
      GoRoute(
        path: '/results',
        name: 'results',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final lat = double.tryParse(q['lat'] ?? '');
          final lon = double.tryParse(q['lon'] ?? '');
          return RoutesResultScreen(destLat: lat, destLon: lon);
        },
      ),
    ],

    // ⬇️ Redirección global:
    // - Si el permiso de ubicación YA está concedido ⇒ no mostramos /permissions.
    // - Si NO está concedido ⇒ enviamos a /permissions (salvo que ya estemos ahí).
    redirect: (context, state) async {
      final path = state.uri.path;

      // Evita loops: si ya estamos en /permissions, no redirigir.
      if (path == '/permissions') return null;

      // Consultamos el estado real del permiso/servicio
      final perm = await PermissionsService.getLocationState();

      // Concedido ⇒ dejamos seguir (Splash → Home, o la ruta que sea)
      if (perm == LocationPermState.granted) {
        // Si el usuario intenta ir a "/" (splash) manualmente, lo mandamos a Home para no ver splash siempre
        if (path == '/' || path.isEmpty) return '/home';
        return null;
      }

      // No concedido / denegado para siempre / servicios off ⇒ forzar /permissions
      if (path != '/permissions') return '/permissions';

      return null;
    },
  );
}
