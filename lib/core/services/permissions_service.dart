import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LocationPermState { granted, denied, deniedForever, servicesOff }

class PermissionsService {
  static const _kEduLocationAccepted = 'edu.location.accepted';

  /// Devuelve el estado actual REAL del permiso + servicios
  static Future<LocationPermState> getLocationState() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermState.servicesOff;

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      return LocationPermState.granted;
    }
    if (perm == LocationPermission.deniedForever)
      return LocationPermState.deniedForever;
    return LocationPermState.denied;
  }

  /// Solicita permiso. Si se concede, marca el flag educativo como aceptado.
  static Future<LocationPermState> requestLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEduLocationAccepted, true);
      return LocationPermState.granted;
    }
    if (perm == LocationPermission.deniedForever)
      return LocationPermState.deniedForever;
    return LocationPermState.denied;
  }

  /// Pantalla educativa ya aceptada al menos una vez.
  static Future<bool> wasEduAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEduLocationAccepted) ?? false;
  }

  /// Por si quieres resetear en pruebas
  static Future<void> resetEduAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEduLocationAccepted);
  }
}
