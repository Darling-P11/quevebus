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

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/permissions',
        name: 'permissions',
        builder: (_, __) => const PermissionsScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/select-on-map',
        name: 'selectOnMap',
        builder: (_, __) => const SelectOnMapScreen(),
      ),
      GoRoute(
        path: '/results',
        name: 'results',
        builder: (ctx, st) {
          final qp = st.uri.queryParameters;
          final dlat = double.tryParse(qp['lat'] ?? '');
          final dlon = double.tryParse(qp['lon'] ?? '');
          return RoutesResultScreen(destLat: dlat, destLon: dlon);
        },
      ),
      GoRoute(
        path: '/itinerary/:id',
        name: 'itineraryDetail',
        builder: (_, st) =>
            ItineraryDetailScreen(itineraryId: st.pathParameters['id'] ?? '1'),
      ),
      GoRoute(
        path: '/menu/permissions',
        name: 'menuPermissions',
        builder: (_, __) => const PermissionsSettingsScreen(),
      ),
      GoRoute(
        path: '/menu/invite',
        name: 'menuInvite',
        builder: (_, __) => const InviteFriendsScreen(),
      ),
      GoRoute(
        path: '/menu/support',
        name: 'menuSupport',
        builder: (_, __) => const SupportScreen(),
      ),
      GoRoute(
        path: '/menu/about',
        name: 'menuAbout',
        builder: (_, __) => const AboutScreen(),
      ),
    ],
  );
}
