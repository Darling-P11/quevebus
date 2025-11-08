// lib/screen/lines/lines_test_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:quevebus/core/services/lines_repository.dart';

class LinesTestScreen extends StatefulWidget {
  const LinesTestScreen({super.key});

  @override
  State<LinesTestScreen> createState() => _LinesTestScreenState();
}

class _LinesTestScreenState extends State<LinesTestScreen> {
  late Future<List<BusLine>> _future;

  @override
  void initState() {
    super.initState();
    // Carga desde el catálogo (lines_catalog.json + tracks)
    _future = LinesRepository().loadFromCatalog();
  }

  // Total de puntos/paradas = suma de los puntos de todos los segmentos
  int _countPoints(BusLine l) =>
      l.segments.fold<int>(0, (acc, seg) => acc + seg.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test de líneas')),
      body: FutureBuilder<List<BusLine>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final lines = snap.data ?? [];
          if (lines.isEmpty) {
            return const Center(child: Text('No hay líneas cargadas'));
          }
          return ListView.separated(
            itemCount: lines.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final l = lines[i];
              final title = (l.name?.isNotEmpty == true)
                  ? l.name!
                  : 'Línea ${l.id}';
              final pts = _countPoints(l);
              return ListTile(
                leading: const Icon(Icons.alt_route),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('ID: ${l.id} • Puntos/Paradas: $pts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/line-preview', extra: l),
              );
            },
          );
        },
      ),
    );
  }
}
