import 'package:flutter/material.dart';

class ItineraryCard extends StatelessWidget {
  final String timeRange; // "1:52 p.m. — 2:13 p.m."
  final int durationMinutes; // 21
  final List<String> lines; // ["Línea 1", "Línea 8"]
  final List<ItineraryStepIcon> icons; // [walk, bus, walk] (solo UI)
  final VoidCallback? onTap;
  final String? subNote; // "cada 7 min", "16 paradas", etc.

  const ItineraryCard({
    super.key,
    required this.timeRange,
    required this.durationMinutes,
    required this.lines,
    required this.icons,
    this.onTap,
    this.subNote,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              const Icon(Icons.directions_transit_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeRange,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // secuencia de iconos: 🚶 > 🚌 > 🚶
                        for (int i = 0; i < icons.length; i++) ...[
                          Icon(_iconFor(icons[i]), size: 16),
                          if (i != icons.length - 1) const Text('›'),
                        ],
                        const SizedBox(width: 8),
                        // chips de líneas
                        ...lines.map((l) => _LineChip(text: l)),
                        if (subNote != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            subNote!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${durationMinutes} min',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ItineraryStepIcon type) {
    switch (type) {
      case ItineraryStepIcon.walk:
        return Icons.directions_walk_rounded;
      case ItineraryStepIcon.bus:
        return Icons.directions_bus_rounded;
      case ItineraryStepIcon.transfer:
        return Icons.compare_arrows_rounded;
    }
  }
}

enum ItineraryStepIcon { walk, bus, transfer }

class _LineChip extends StatelessWidget {
  final String text;
  const _LineChip({required this.text});

  @override
  Widget build(BuildContext context) {
    // estilito simple y limpio
    return Chip(
      label: Text(text),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
