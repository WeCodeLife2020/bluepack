import 'package:shared_preferences/shared_preferences.dart';
import '../models/scale_reading.dart';

/// Handles persistent storage of scale reading history.
class ReadingHistoryService {
  ReadingHistoryService._();

  static const _scaleKey = 'scale_readings';

  /// Load all scale readings, newest first.
  static Future<List<ScaleReading>> loadScaleReadings() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_scaleKey) ?? [];
    final readings = list.map((s) => ScaleReading.fromJsonString(s)).toList();
    readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return readings;
  }

  /// Save a new scale reading.
  static Future<void> addScaleReading(ScaleReading reading) async {
    final readings = await loadScaleReadings();
    readings.insert(0, reading);
    await _persistScale(readings);
  }

  /// Delete a reading by timestamp.
  static Future<void> deleteScaleReading(DateTime timestamp) async {
    final readings = await loadScaleReadings();
    readings.removeWhere((r) =>
        r.timestamp.millisecondsSinceEpoch == timestamp.millisecondsSinceEpoch);
    await _persistScale(readings);
  }

  /// Clear all scale readings.
  static Future<void> clearScaleReadings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scaleKey);
  }

  static Future<void> _persistScale(List<ScaleReading> readings) async {
    final prefs = await SharedPreferences.getInstance();
    final list = readings.map((r) => r.toJsonString()).toList();
    await prefs.setStringList(_scaleKey, list);
  }
}
