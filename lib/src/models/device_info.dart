/// Represents a discovered BLE device.
class LepuDeviceInfo {
  final String name;
  final String mac;
  final int model;
  final int rssi;

  const LepuDeviceInfo({
    required this.name,
    required this.mac,
    required this.model,
    required this.rssi,
  });

  factory LepuDeviceInfo.fromMap(Map<String, dynamic> map) {
    return LepuDeviceInfo(
      name: (map['name'] as String?) ?? '',
      mac: (map['mac'] as String?) ?? '',
      model: (map['model'] as int?) ?? -1,
      rssi: (map['rssi'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'mac': mac,
    'model': model,
    'rssi': rssi,
  };

  /// Returns a human-readable device type based on the model number.
  String get deviceType {
    if (LepuDeviceModels.isEcg(model)) return 'ecg';
    if (LepuDeviceModels.isOximeter(model)) return 'oximeter';
    if (LepuDeviceModels.isBp(model)) return 'bp';
    return 'unknown';
  }

  @override
  String toString() => 'LepuDeviceInfo($name, $mac, model=$model, rssi=$rssi)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LepuDeviceInfo && mac == other.mac && model == other.model;

  @override
  int get hashCode => mac.hashCode ^ model.hashCode;
}

/// Helper class for device model classification.
class LepuDeviceModels {
  LepuDeviceModels._();

  // ── ECG models (from Bluetooth.MODEL_* constants) ─────────────────
  static const ecgModels = <int>{
    // ER1 family
    11, 28, 27, 64, 65, 78, 82, 91,
    // ER2 family
    12, 13, 33, 75, 29, 30, 14,
    // ER3
    38, 67,
  };

  // ── Oximeter models ───────────────────────────────────────────────
  static const oximeterModels = <int>{
    // O2Ring family
    6, 7, 18, 57, 19, 20, 21, 24, 22, 23, 25, 26, 58,
    59, 60, 61, 63, 79, 80, 81, 83, 84, 85,
    // PC60FW family
    1, 31, 32, 34, 3, 4, 35, 36, 37, 39, 40, 41, 42, 43,
    44, 45, 46, 47, 48, 62, 76, 77, 93,
    // PF10AW1 family
    73, 70, 71, 72,
    // OxyII family
    86, 87, 88, 89,
  };

  // ── BP models ─────────────────────────────────────────────────────
  static const bpModels = <int>{
    // BP2 family
    15, 16, 17, 50, 49,
    // BP3 family
    51, 52, 53, 54, 55, 56, 90, 92, 94, 95, 96,
    // Others
    10, 69,
  };

  static bool isEcg(int model) => ecgModels.contains(model);
  static bool isOximeter(int model) => oximeterModels.contains(model);
  static bool isBp(int model) => bpModels.contains(model);
}
