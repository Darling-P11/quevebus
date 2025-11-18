import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsSettingsScreen extends StatefulWidget {
  const PermissionsSettingsScreen({super.key});

  @override
  State<PermissionsSettingsScreen> createState() =>
      _PermissionsSettingsScreenState();
}

class _PermissionsSettingsScreenState extends State<PermissionsSettingsScreen> {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _loadLocationStatus();
  }

  Future<void> _loadLocationStatus() async {
    final status = await Permission.locationWhenInUse.status;
    if (!mounted) return;
    setState(() {
      _locationStatus = status;
      _loadingStatus = false;
    });
  }

  String _statusLabel(PermissionStatus status) {
    if (status.isGranted) return 'Concedido';
    if (status.isPermanentlyDenied) return 'Bloqueado';
    if (status.isRestricted) return 'Restringido';
    if (status.isDenied) return 'Denegado';
    return 'Desconocido';
  }

  Color _statusColor(PermissionStatus status, ColorScheme cs) {
    if (status.isGranted) return Colors.green.shade600;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return Colors.red.shade600;
    }
    if (status.isDenied) return Colors.orange.shade700;
    return cs.primary;
  }

  Future<void> _requestOrOpenSettings() async {
    // Si está bloqueado permanentemente, no sirve pedir de nuevo, se abre ajustes
    if (_locationStatus.isPermanentlyDenied || _locationStatus.isRestricted) {
      final ok = await openAppSettings();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron abrir los ajustes de la app.'),
          ),
        );
      }
      return;
    }

    final result = await Permission.locationWhenInUse.request();
    if (!mounted) return;

    setState(() => _locationStatus = result);

    final granted = result.isGranted;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Permiso de ubicación concedido'
              : 'Permiso de ubicación denegado',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final statusText = _statusLabel(_locationStatus);
    final statusColor = _statusColor(_locationStatus, cs);

    final isBlocked =
        _locationStatus.isPermanentlyDenied || _locationStatus.isRestricted;

    final mainButtonLabel = isBlocked
        ? 'Abrir ajustes'
        : (_locationStatus.isGranted ? 'Volver a solicitar' : 'Conceder');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            // Si hay algo que hacer pop, lo hacemos; si no, volvemos al home
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/'); // o la ruta que uses como home
            }
          },
        ),
        title: const Text('Permisos'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Intro
          Text(
            'Para que QueveBus pueda mostrarte paradas cercanas y calcular rutas desde tu posición actual, es necesario que autorices el acceso a la ubicación.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          // Card de ubicación
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila principal: icono + info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: cs.primary.withOpacity(.08),
                        child: Icon(
                          Icons.pin_drop,
                          color: cs.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ubicación',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Necesaria para localizarte en el mapa y sugerir paradas cercanas.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_loadingStatus)
                              const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: statusColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Botón alineado abajo a la derecha, en una fila separada
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _loadingStatus ? null : _requestOrOpenSettings,
                      child: Text(mainButtonLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Info + acceso directo a settings
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.settings_applications_outlined),
            title: const Text(
              'Abrir ajustes del sistema',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Si el permiso está bloqueado, puedes modificarlo manualmente desde aquí.',
            ),
            onTap: openAppSettings,
          ),
        ],
      ),
    );
  }
}
