import 'dart:convert';

/// A device that has been paired/saved by the user for quick reconnection.
class SavedDevice {
  final String mac;
  final String name;
  final String sdk;   // "lepu", "icomon", or "lescale"
  final int model;
  final String deviceType; // "ecg", "oximeter", "bp", "scale", "unknown"

  const SavedDevice({
    required this.mac,
    required this.name,
    required this.sdk,
    required this.model,
    required this.deviceType,
  });

  factory SavedDevice.fromJson(Map<String, dynamic> json) {
    return SavedDevice(
      mac: json['mac'] as String,
      name: json['name'] as String,
      sdk: json['sdk'] as String,
      model: json['model'] as int,
      deviceType: json['deviceType'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'mac': mac,
    'name': name,
    'sdk': sdk,
    'model': model,
    'deviceType': deviceType,
  };

  String toJsonString() => jsonEncode(toJson());

  factory SavedDevice.fromJsonString(String s) =>
      SavedDevice.fromJson(jsonDecode(s) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedDevice && mac == other.mac;

  @override
  int get hashCode => mac.hashCode;

  @override
  String toString() => 'SavedDevice($name, $mac, sdk=$sdk)';
}
