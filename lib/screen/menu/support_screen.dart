import 'package:flutter/material.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _SupportItem(
        Icons.help_outline,
        'Centro de ayuda',
        'Preguntas frecuentes y guías',
      ),
      _SupportItem(
        Icons.chat_bubble_outline,
        'Enviar un mensaje',
        'Nuestro equipo te responderá',
      ),
      _SupportItem(Icons.email_outlined, 'Correo', 'soporte@quevebus.app'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Soporte técnico')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        // 👇 renombro el primer parámetro a ctx para usarlo adentro
        itemBuilder: (ctx, i) => Card(
          child: ListTile(
            leading: Icon(items[i].icon),
            title: Text(
              items[i].title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(items[i].subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Opción A: usar el ctx del itemBuilder
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Prototipo: abrir soporte'),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              // O, si prefieres, puedes usar el context del build:
              // ScaffoldMessenger.of(context).showSnackBar(...);
            },
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: items.length,
      ),
    );
  }
}

class _SupportItem {
  final IconData icon;
  final String title;
  final String subtitle;
  _SupportItem(this.icon, this.title, this.subtitle);
}
