import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            CircleAvatar(
              radius: 44,
              backgroundColor: cs.primary.withOpacity(.12),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset('assets/images/logo_quevebus.png'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'QueveBus',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Versión 0.1.0 (Prototipo)',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            const Text(
              'App comunitaria para planear tus viajes en bus dentro de Quevedo. '
              '..',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            Text(
              '© ${DateTime.now().year} QueveBus',
              style: const TextStyle(color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
