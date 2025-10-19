import 'package:flutter/material.dart';

class InviteFriendsScreen extends StatelessWidget {
  const InviteFriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Invitar amigos')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Icon(Icons.group_add_rounded, size: 90, color: cs.primary),
            const SizedBox(height: 12),
            const Text(
              'Comparte QueveBus con tus amigos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Envíales tu enlace de invitación para que también encuentren la mejor ruta en bus.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Compartir enlace de invitación'),
                    ),
                  );
                },
                child: const Text('Compartir enlace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
