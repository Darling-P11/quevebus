import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentDestination {
  final String label;
  final double lat;
  final double lon;
  final DateTime at;

  RecentDestination({
    required this.label,
    required this.lat,
    required this.lon,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'lat': lat,
    'lon': lon,
    'at': at.toIso8601String(),
  };

  static RecentDestination fromJson(Map<String, dynamic> j) =>
      RecentDestination(
        label: j['label'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

class RecentsService {
  static const _kKey = 'recents.destinations';
  static const _maxItems = 10;

  static Future<List<RecentDestination>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(RecentDestination.fromJson)
        .toList();
    // Ordenar por fecha desc
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  static Future<void> add(RecentDestination item) async {
    final prefs = await SharedPreferences.getInstance();
    final curr = await load();

    // Evitar duplicados exactos (misma lat/lon y label)
    curr.removeWhere(
      (e) =>
          (e.lat - item.lat).abs() < 1e-6 &&
          (e.lon - item.lon).abs() < 1e-6 &&
          e.label == item.label,
    );

    curr.insert(0, item);
    if (curr.length > _maxItems) {
      curr.removeRange(_maxItems, curr.length);
    }
    final raw = jsonEncode(curr.map((e) => e.toJson()).toList());
    await prefs.setString(_kKey, raw);
  }
}
