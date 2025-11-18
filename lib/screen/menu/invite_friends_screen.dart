import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class InviteFriendsScreen extends StatelessWidget {
  const InviteFriendsScreen({super.key});

  static const String _inviteLink = 'https://quevebus.app/invitar';

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _inviteLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado al portapapeles')),
    );
  }

  void _shareLink(BuildContext context) {
    // Aquí luego se puede integrar share_plus:
    // Share.share('Prueba QueveBus: $_inviteLink');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Prueba...')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/'); // ruta principal de la app
            }
          },
        ),
        title: const Text('Invitar amigos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Icon(Icons.group_add_rounded, size: 82, color: cs.primary),
            const SizedBox(height: 12),
            const Text(
              'Comparte QueveBus con tus amigos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ayúdalos a encontrar la mejor ruta en bus en Quevedo compartiendo el enlace de descarga.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5),
            ),

            const SizedBox(height: 20),

            // Tarjeta con el enlace de invitación
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu enlace de invitación',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _inviteLink,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () => _copyLink(context),
                            tooltip: 'Copiar enlace',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Puedes pegarlo en WhatsApp, Telegram u otra app para que se unan.',
                      style: TextStyle(fontSize: 11.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Botón principal de compartir
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _shareLink(context),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Compartir enlace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
