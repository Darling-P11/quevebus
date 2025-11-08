// lib/core/routing/models.dart
import 'package:latlong2/latlong.dart';

enum LegMode { walk, bus }

class Leg {
  final LegMode mode;
  final String? lineId;
  final List<LatLng> shape; // polilínea de ese tramo
  final double minutes;
  Leg({
    required this.mode,
    required this.shape,
    required this.minutes,
    this.lineId,
  });
}

class Itinerary {
  final List<Leg> legs;
  double get totalMinutes => legs.fold(0.0, (s, l) => s + l.minutes);
  int get transfers =>
      legs
          .where((l) => l.mode == LegMode.bus)
          .map((l) => l.lineId)
          .toList()
          .length -
      1;

  Itinerary(this.legs);
}
