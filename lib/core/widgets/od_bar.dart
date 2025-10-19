import 'package:flutter/material.dart';

class ODBar extends StatelessWidget {
  final String originLabel;
  final String originValue;
  final String destinationLabel;
  final String destinationValue;
  final VoidCallback? onSwap;
  final VoidCallback? onEditOrigin;
  final VoidCallback? onEditDestination;

  const ODBar({
    super.key,
    this.originLabel = 'Origen',
    required this.originValue,
    this.destinationLabel = 'Destino',
    required this.destinationValue,
    this.onSwap,
    this.onEditOrigin,
    this.onEditDestination,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [
          _ODRow(
            icon: Icons.radio_button_checked,
            label: originLabel,
            value: originValue,
            onEdit: onEditOrigin,
          ),
          const Divider(height: 16),
          _ODRow(
            icon: Icons.place,
            label: destinationLabel,
            value: destinationValue,
            onEdit: onEditDestination,
          ),
          if (onSwap != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSwap,
                icon: const Icon(Icons.swap_vert_rounded),
                label: const Text('Intercambiar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ODRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const _ODRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Colors.black54,
      fontWeight: FontWeight.w600,
    );

    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue),
        const SizedBox(width: 8),
        Text(label, style: labelStyle),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (onEdit != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
      ],
    );
  }
}
