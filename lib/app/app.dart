import 'package:flutter/material.dart';
import 'package:quevebus/app/app_router.dart';
import 'package:quevebus/core/theme.dart';

class QueveBusApp extends StatelessWidget {
  const QueveBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();
    return MaterialApp.router(
      title: 'QueveBus (Prototipo)',
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
