import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_device.dart';

/// Handles persistent storage of saved/paired devices.
class DeviceStorageService {
  DeviceStorageService._();

  static const _key = 'saved_devices';

  /// Load all saved devices from disk.
  static Future<List<SavedDevice>> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((s) => SavedDevice.fromJsonString(s)).toList();
  }

  /// Save a device. Replaces any existing entry with the same MAC.
  static Future<void> saveDevice(SavedDevice device) async {
    final devices = await loadDevices();
    devices.removeWhere((d) => d.mac == device.mac);
    devices.add(device);
    await _persist(devices);
  }

  /// Remove a saved device by MAC address.
  static Future<void> removeDevice(String mac) async {
    final devices = await loadDevices();
    devices.removeWhere((d) => d.mac == mac);
    await _persist(devices);
  }

  /// Check if a device with the given MAC is already saved.
  static Future<bool> isDeviceSaved(String mac) async {
    final devices = await loadDevices();
    return devices.any((d) => d.mac == mac);
  }

  static Future<void> _persist(List<SavedDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final list = devices.map((d) => d.toJsonString()).toList();
    await prefs.setStringList(_key, list);
  }
}
