// lib/screen/home/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppSideDrawer extends StatelessWidget {
  const AppSideDrawer({super.key});

  void _goAndClose(BuildContext context, String route) {
    Navigator.of(context).pop(); // cierra el drawer
    context.go(route);
  }

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
            // ---------- HEADER ----------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/images/logo_quevebus.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'QueveBus',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Encuentra tu ruta de bus en Quevedo',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ---------- CONTENIDO SCROLLEABLE ----------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Explorar'),

                    _ItemTile(
                      icon: Icons.alt_route,
                      text: 'Rutas de buses',
                      subtitle: 'Ver recorridos y probar líneas',
                      onTap: () => _goAndClose(context, '/menu/lines-test'),
                    ),

                    const SizedBox(height: 4),

                    const _SectionTitle('Configuración'),

                    _ItemTile(
                      icon: Icons.verified_user_outlined,
                      text: 'Permisos',
                      subtitle: 'Ubicación y acceso al dispositivo',
                      onTap: () => _goAndClose(context, '/menu/permissions'),
                    ),

                    const SizedBox(height: 4),

                    const _SectionTitle('Compartir y ayuda'),

                    _ItemTile(
                      icon: Icons.group_add_outlined,
                      text: 'Invitar amigos',
                      subtitle: 'Comparte QueveBus con otras personas',
                      onTap: () => _goAndClose(context, '/menu/invite'),
                    ),
                    _ItemTile(
                      icon: Icons.headset_mic_outlined,
                      text: 'Soporte técnico',
                      subtitle: 'Reporta un problema o envía sugerencias',
                      onTap: () => _goAndClose(context, '/menu/support'),
                    ),
                    _ItemTile(
                      icon: Icons.info_outline,
                      text: 'Acerca de',
                      subtitle: 'Versión, créditos y detalles de la app',
                      onTap: () => _goAndClose(context, '/menu/about'),
                    ),
                  ],
                ),
              ),
            ),

            // ---------- FOOTER ----------
            const Divider(height: 0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_bus_outlined,
                    size: 18,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'v1.0 Estable',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.black45),
                  ),
                  const Spacer(),
                  Text(
                    'Quevedo, EC',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.black38),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- TÍTULO DE SECCIÓN ----------
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: Colors.black54,
        ),
      ),
    );
  }
}

// ---------- ITEM DEL MENÚ ----------
class _ItemTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtitle;
  final VoidCallback onTap;

  const _ItemTile({
    required this.icon,
    required this.text,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: cs.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.black38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
