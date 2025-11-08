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
  List<BusLine> _all = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<BusLine>> _load() async {
    final data = await LinesRepository().loadFromCatalog();
    _all = data;
    return data;
  }

  // Total de puntos/paradas = suma de los puntos de todos los segmentos
  int _countPoints(BusLine l) =>
      l.segments.fold<int>(0, (acc, seg) => acc + seg.length);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Líneas de buses'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      body: FutureBuilder<List<BusLine>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final lines = _filtered(_all, _query);
          if (lines.isEmpty) {
            return _EmptyState(
              onReload: () => setState(() => _future = _load()),
            );
          }

          return Column(
            children: [
              // Encabezado moderno con métricas
              _HeaderStats(
                total: _all.length,
                visibles: lines.length,
                onChanged: (v) => setState(() => _query = v),
              ),

              // Lista
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => setState(() => _future = _load()),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final l = lines[i];
                      final title = (l.name?.isNotEmpty == true)
                          ? l.name!
                          : 'Línea ${l.id}';
                      final pts = _countPoints(l);
                      final segs = l.segments.length;

                      return _LineCard(
                        color: _palette[i % _palette.length],
                        title: title,
                        subtitleId: l.id,
                        points: pts,
                        segments: segs,
                        onTap: () => context.push('/line-preview', extra: l),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<BusLine> _filtered(List<BusLine> src, String q) {
    if (q.trim().isEmpty) return src;
    final qq = q.toLowerCase();
    return src.where((l) {
      final name = (l.name ?? '').toLowerCase();
      final id = l.id.toLowerCase();
      return name.contains(qq) || id.contains(qq);
    }).toList();
  }
}

/// ---------- UI Helpers ----------

class _HeaderStats extends StatelessWidget {
  final int total;
  final int visibles;
  final ValueChanged<String> onChanged;

  const _HeaderStats({
    required this.total,
    required this.visibles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Métricas
            Row(
              children: [
                _ChipStat(
                  icon: Icons.directions_bus,
                  label: 'Total',
                  value: '$total',
                ),
                const SizedBox(width: 8),
                _ChipStat(
                  icon: Icons.visibility,
                  label: 'Mostrando',
                  value: '$visibles',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Búsqueda
            TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Buscar por nombre o ID...',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ChipStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label: $value'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }
}

class _LineCard extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitleId;
  final int points;
  final int segments;
  final VoidCallback onTap;

  const _LineCard({
    required this.color,
    required this.title,
    required this.subtitleId,
    required this.points,
    required this.segments,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              // Avatar de color con ícono
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.alt_route_rounded, color: color, size: 26),
              ),
              const SizedBox(width: 12),

              // Título y chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: -6,
                      children: [
                        _pill(text: 'ID: $subtitleId'),
                        _pill(text: 'Pts: $points'),
                        _pill(text: 'Seg: $segments'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onReload;
  const _EmptyState({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_bus_rounded,
            size: 46,
            color: Colors.black45,
          ),
          const SizedBox(height: 8),
          const Text('No hay líneas cargadas'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onReload,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

const _palette = <Color>[
  Color(0xFF1565C0),
  Color(0xFF00897B),
  Color(0xFF6A1B9A),
  Color(0xFFEF6C00),
  Color(0xFF2E7D32),
  Color(0xFF455A64),
];
