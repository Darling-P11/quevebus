// lib/screen/home/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppSideDrawer extends StatelessWidget {
  const AppSideDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo_quevebus.png',
                    width: 84,
                    height: 84,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'QueveBus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 👇 NUEVO: Test de líneas
            _ItemTile(
              icon: Icons.alt_route,
              text: 'Rutas de buses',
              onTap: () => context.go('/menu/lines-test'),
            ),

            _ItemTile(
              icon: Icons.verified_user_outlined,
              text: 'Permisos',
              onTap: () => context.go('/menu/permissions'),
            ),
            _ItemTile(
              icon: Icons.group_add_outlined,
              text: 'Invitar amigos',
              onTap: () => context.go('/menu/invite'),
            ),
            _ItemTile(
              icon: Icons.headset_mic_outlined,
              text: 'Soporte técnico',
              onTap: () => context.go('/menu/support'),
            ),
            _ItemTile(
              icon: Icons.info_outline,
              text: 'Acerca de',
              onTap: () => context.go('/menu/about'),
            ),

            const Spacer(),
            const Divider(height: 0),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'v0.1.0 • prototipo',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _ItemTile({
    required this.icon,
    required this.text,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
