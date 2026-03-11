import 'dart:convert';
import 'dart:math' show pow;

/// A single scale measurement reading with all body composition data.
class ScaleReading {
  final DateTime timestamp;
  final double weightKg;
  final double bmi;
  final int heartRate;
  final double bodyFat;       // %
  final double fatMass;       // kg
  final double muscle;        // kg
  final double skeletalMuscle; // kg
  final double water;         // %
  final double bone;          // kg
  final double protein;       // %
  final int bmr;              // kcal
  final double visceral;
  final double subcutaneous;  // %
  final double bodyAge;
  final double cardiacIndex;  // L/min/m²
  final String deviceMac;
  final String deviceName;

  const ScaleReading({
    required this.timestamp,
    required this.weightKg,
    this.bmi = 0,
    this.heartRate = 0,
    this.bodyFat = 0,
    this.fatMass = 0,
    this.muscle = 0,
    this.skeletalMuscle = 0,
    this.water = 0,
    this.bone = 0,
    this.protein = 0,
    this.bmr = 0,
    this.visceral = 0,
    this.subcutaneous = 0,
    this.bodyAge = 0,
    this.cardiacIndex = 0,
    this.deviceMac = '',
    this.deviceName = '',
  });

  /// Create a ScaleReading from the rtData event map + calculated CI.
  factory ScaleReading.fromEvent(
    Map<String, dynamic> event, {
    double heightCm = 170,
    String deviceName = '',
  }) {
    final w = _toDouble(event['weightKg']);
    final hr = _toInt(event['heartRate']);

    // Calculate CI
    double ci = 0;
    if (hr > 0 && w > 0 && heightCm > 0) {
      final bsa = 0.007184 * pow(heightCm, 0.725) * pow(w, 0.425);
      if (bsa > 0) {
        ci = (hr * 70.0 / 1000.0) / bsa;
      }
    }

    return ScaleReading(
      timestamp: DateTime.now(),
      weightKg: _round1(w),
      bmi: _round1(_toDouble(event['bmi'])),
      heartRate: hr,
      bodyFat: _round1(_toDouble(event['fat'])),
      fatMass: _round1(_toDouble(event['fat_mass'])),
      muscle: _round1(_toDouble(event['muscle'])),
      skeletalMuscle: _round1(_toDouble(event['skeletal_muscle'])),
      water: _round1(_toDouble(event['water'])),
      bone: _round1(_toDouble(event['bone'])),
      protein: _round1(_toDouble(event['protein'])),
      bmr: _toInt(event['bmr']),
      visceral: _round1(_toDouble(event['visceral'])),
      subcutaneous: _round1(_toDouble(event['subcutaneous'])),
      bodyAge: _round1(_toDouble(event['body_age'])),
      cardiacIndex: _round1(ci),
      deviceMac: event['mac']?.toString() ?? '',
      deviceName: deviceName,
    );
  }

  factory ScaleReading.fromJson(Map<String, dynamic> j) => ScaleReading(
    timestamp: DateTime.parse(j['timestamp'] as String),
    weightKg: (j['weightKg'] as num).toDouble(),
    bmi: (j['bmi'] as num).toDouble(),
    heartRate: j['heartRate'] as int,
    bodyFat: (j['bodyFat'] as num).toDouble(),
    fatMass: (j['fatMass'] as num).toDouble(),
    muscle: (j['muscle'] as num).toDouble(),
    skeletalMuscle: (j['skeletalMuscle'] as num).toDouble(),
    water: (j['water'] as num).toDouble(),
    bone: (j['bone'] as num).toDouble(),
    protein: (j['protein'] as num).toDouble(),
    bmr: j['bmr'] as int,
    visceral: (j['visceral'] as num).toDouble(),
    subcutaneous: (j['subcutaneous'] as num).toDouble(),
    bodyAge: (j['bodyAge'] as num).toDouble(),
    cardiacIndex: (j['cardiacIndex'] as num).toDouble(),
    deviceMac: j['deviceMac'] as String? ?? '',
    deviceName: j['deviceName'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'weightKg': weightKg,
    'bmi': bmi,
    'heartRate': heartRate,
    'bodyFat': bodyFat,
    'fatMass': fatMass,
    'muscle': muscle,
    'skeletalMuscle': skeletalMuscle,
    'water': water,
    'bone': bone,
    'protein': protein,
    'bmr': bmr,
    'visceral': visceral,
    'subcutaneous': subcutaneous,
    'bodyAge': bodyAge,
    'cardiacIndex': cardiacIndex,
    'deviceMac': deviceMac,
    'deviceName': deviceName,
  };

  String toJsonString() => jsonEncode(toJson());

  factory ScaleReading.fromJsonString(String s) =>
      ScaleReading.fromJson(jsonDecode(s) as Map<String, dynamic>);

  // Helpers
  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _round1(double v) => (v * 10).roundToDouble() / 10;
}
