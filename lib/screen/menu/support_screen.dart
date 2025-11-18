import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _supportEmail = 'soporte@quevebus.app';

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correo copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final faqs = [
      FAQ(
        question: '¿Por qué la app no detecta mi ubicación?',
        answer:
            'Asegúrate de que el GPS esté activado y que QueveBus tenga permiso de ubicación. '
            'Puedes verificarlo desde Configuración > Aplicaciones > QueveBus > Permisos.',
      ),
      FAQ(
        question: '¿De dónde provienen las rutas de buses?',
        answer:
            'Las rutas y paradas provienen de datos comunitarios y levantamientos locales en la ciudad de Quevedo.',
      ),
      FAQ(
        question: '¿Qué hago si una ruta está mal o actualizada?',
        answer:
            'Puedes enviarnos la corrección al correo de soporte para revisarla e incluirla en la próxima versión.',
      ),
      FAQ(
        question: '¿La app funciona sin internet?',
        answer:
            'Puedes ver el mapa y tu ubicación, pero algunas funciones como búsqueda y sugerencias de ruta necesitan conexión.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Soporte técnico'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ----------- Centro de ayuda -----------
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Centro de ayuda',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Encuentra respuestas a las preguntas más frecuentes.',
                    style: TextStyle(fontSize: 13.5, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),

                  // ----------- Preguntas frecuentes -----------
                  ...faqs.map((faq) => _FAQTile(faq: faq)).toList(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ----------- Correo de soporte -----------
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Correo de soporte',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 22, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _supportEmail,
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copiar correo',
                        icon: const Icon(Icons.copy_rounded),
                        onPressed: () => _copyEmail(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Puedes escribirnos para reportar errores o recomendar mejoras.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------ MODEL FAQ ------------------------
class FAQ {
  final String question;
  final String answer;
  FAQ({required this.question, required this.answer});
}

// ------------------------ WIDGET FAQ EXPANDIBLE ------------------------
class _FAQTile extends StatefulWidget {
  final FAQ faq;
  const _FAQTile({required this.faq});

  @override
  State<_FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<_FAQTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: cs.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.faq.question,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 34, right: 6, bottom: 12),
            child: Text(
              widget.faq.answer,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ),
        const Divider(height: 0),
      ],
    );
  }
}
