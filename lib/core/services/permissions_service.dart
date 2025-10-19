import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  /// Pide permiso de ubicación "WhenInUse".
  /// Devuelve true si fue concedido.
  static Future<bool> requestLocation() async {
    // Verifica estado actual primero
    final status = await Permission.locationWhenInUse.status;

    if (status.isGranted) return true;

    // Solicita
    final result = await Permission.locationWhenInUse.request();

    if (result.isGranted) {
      return true;
    } else if (result.isPermanentlyDenied) {
      // Abre ajustes si el usuario lo bloqueó permanentemente
      await openAppSettings();
      return false;
    } else {
      return false;
    }
  }
}
