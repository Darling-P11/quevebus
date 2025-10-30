import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart'; // para abrir ajustes si está denegado para siempre
import 'package:quevebus/core/services/permissions_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _checking = true; // ⬅️ para auto-saltar si ya está concedido
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _precheck();
  }

  Future<void> _precheck() async {
    final st = await PermissionsService.getLocationState();
    if (!mounted) return;
    if (st == LocationPermState.granted) {
      // Ya tiene permiso: no mostramos esta pantalla
      context.go('/home');
    } else {
      setState(() => _checking = false);
    }
  }

  Future<void> _handleAccept() async {
    if (_loading) return;
    setState(() => _loading = true);

    final st = await PermissionsService.requestLocation();

    if (!mounted) return;
    setState(() => _loading = false);

    if (st == LocationPermState.granted) {
      context.go('/home');
      return;
    }

    if (st == LocationPermState.deniedForever) {
      // Denegado permanentemente: sugerir ir a Ajustes
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Permiso requerido'),
          content: const Text(
            'Debes habilitar la ubicación desde Ajustes del sistema para usar el mapa y planificar rutas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openAppSettings();
              },
              child: const Text('Abrir Ajustes'),
            ),
          ],
        ),
      );
      return;
    }

    // Denegado temporalmente o servicios apagados: feedback suave
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se otorgó el permiso de ubicación. Puedes activarlo luego en Ajustes.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

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

              // Botón secundario (nota: si tu redirect fuerza permisos, esto volverá aquí)
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
