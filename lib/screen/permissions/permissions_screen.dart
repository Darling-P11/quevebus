import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quevebus/core/services/permissions_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _loading = false;

  Future<void> _handleAccept() async {
    if (_loading) return;
    setState(() => _loading = true);

    final ok = await PermissionsService.requestLocation();

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      context.go('/home');
    } else {
      // Feedback suave si fue denegado.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se otorgó el permiso de ubicación. Puedes activarlo luego en Ajustes.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Imagen grande centrada (tu asset)
              Image.asset(
                'assets/images/permiso_pin.png',
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),

              const Text(
                'Permitir acceso a la ubicación',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),

              const Text(
                'Necesitamos acceso a tu ubicación para ofrecerte un mejor servicio',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),

              const Spacer(),

              // Botón principal
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _handleAccept,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: cs.primary,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Aceptar', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 8),

              // Botón secundario
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Ahora no'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
