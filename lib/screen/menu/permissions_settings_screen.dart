import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsSettingsScreen extends StatelessWidget {
  const PermissionsSettingsScreen({super.key});

  Future<void> _requestLocation(BuildContext context) async {
    final result = await Permission.locationWhenInUse.request();
    final granted = result.isGranted;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted ? 'Permiso de ubicación concedido' : 'Permiso denegado',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Permisos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primary.withOpacity(.1),
                child: Icon(Icons.pin_drop, color: cs.primary),
              ),
              title: const Text('Ubicación'),
              subtitle: const Text(
                'Permite que la app obtenga tu ubicación para mostrar paradas cercanas.',
              ),
              trailing: FilledButton(
                onPressed: () => _requestLocation(context),
                child: const Text('Conceder'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.settings_applications_outlined),
            title: const Text('Abrir ajustes del sistema'),
            onTap: openAppSettings,
          ),
        ],
      ),
    );
  }
}
