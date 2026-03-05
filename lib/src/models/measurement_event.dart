/// Real-time measurement data from a connected device.
class LepuMeasurementEvent {
  /// Event type — always "rtData"
  final String event;

  /// Device type: "ecg", "oximeter", "bp"
  final String deviceType;

  /// Device family: "er1", "er2", "oxy", "pc60fw", "pf10aw1", "bp2"
  final String deviceFamily;

  /// SDK model number
  final int model;

  // ── ECG params ────────────────────────────────────────────────────
  /// Heart rate (beats per minute)
  final int? hr;

  /// ECG recording time (seconds)
  final int? recordTime;

  /// ECG device current status
  /// 0=idle, 1=preparing, 2=measuring, 3=saving, 4=saved,
  /// 5=<30s not saved, 6=6 retests, 7=lead off
  final int? curStatus;

  // ── Oximeter params ───────────────────────────────────────────────
  /// Blood oxygen saturation (0-100%)
  final int? spo2;

  /// Pulse rate (beats per minute)
  final int? pr;

  /// Perfusion index (0-25.5%)
  final double? pi;

  /// Oximeter sensor state: 0=lead off, 1=lead on
  final int? state;

  // ── BP params ─────────────────────────────────────────────────────
  /// BP measurement sub-type: bp_measuring, bp_result, ecg_measuring, ecg_result
  final String? measureType;

  /// Systolic pressure
  final int? sys;

  /// Diastolic pressure
  final int? dia;

  /// Mean pressure
  final int? mean;

  /// Current cuff pressure during measurement
  final int? pressure;

  /// BP result code (0=normal, 1=unable, 2=disorder, 3=weak, 4+=error)
  final int? result;

  /// BP/ECG device status
  final int? deviceStatus;

  // ── QRS / diagnosis (BP2 ECG result) ──────────────────────────────
  final int? qrs;
  final int? pvcs;
  final int? qtc;
  final String? resultMessage;

  // ── Vitals timing ─────────────────────────────────────────────────
  final int? curDuration;
  final bool? isLeadOff;
  final bool? isPoolSignal;

  // ── Battery ───────────────────────────────────────────────────────
  /// Battery level (0-100)
  final int? battery;

  /// Battery state: 0=no charge, 1=charging, 2=complete, 3=low
  final int? batteryState;

  /// Battery level for PF10AW1 (0-3)
  final int? batLevel;

  /// Battery percent for BP2
  final int? batteryPercent;

  /// Battery status for BP2
  final int? batteryStatus;

  // ── Sampling ──────────────────────────────────────────────────────
  /// ECG sampling rate (Hz)
  final int? samplingRate;

  /// mV conversion factor
  final double? mvConversion;

  const LepuMeasurementEvent({
    required this.event,
    required this.deviceType,
    required this.deviceFamily,
    required this.model,
    this.hr,
    this.recordTime,
    this.curStatus,
    this.spo2,
    this.pr,
    this.pi,
    this.state,
    this.measureType,
    this.sys,
    this.dia,
    this.mean,
    this.pressure,
    this.result,
    this.deviceStatus,
    this.qrs,
    this.pvcs,
    this.qtc,
    this.resultMessage,
    this.curDuration,
    this.isLeadOff,
    this.isPoolSignal,
    this.battery,
    this.batteryState,
    this.batLevel,
    this.batteryPercent,
    this.batteryStatus,
    this.samplingRate,
    this.mvConversion,
  });

  factory LepuMeasurementEvent.fromMap(Map<String, dynamic> map) {
    return LepuMeasurementEvent(
      event: (map['event'] as String?) ?? 'rtData',
      deviceType: (map['deviceType'] as String?) ?? 'unknown',
      deviceFamily: (map['deviceFamily'] as String?) ?? 'unknown',
      model: (map['model'] as int?) ?? -1,
      hr: map['hr'] as int?,
      recordTime: map['recordTime'] as int?,
      curStatus: map['curStatus'] as int?,
      spo2: map['spo2'] as int?,
      pr: map['pr'] as int?,
      pi: (map['pi'] is num) ? (map['pi'] as num).toDouble() : null,
      state: map['state'] as int?,
      measureType: map['measureType'] as String?,
      sys: map['sys'] as int?,
      dia: map['dia'] as int?,
      mean: map['mean'] as int?,
      pressure: map['pressure'] as int?,
      result: map['result'] as int?,
      deviceStatus: map['deviceStatus'] as int?,
      qrs: map['qrs'] as int?,
      pvcs: map['pvcs'] as int?,
      qtc: map['qtc'] as int?,
      resultMessage: map['resultMessage'] as String?,
      curDuration: map['curDuration'] as int?,
      isLeadOff: map['isLeadOff'] as bool?,
      isPoolSignal: map['isPoolSignal'] as bool?,
      battery: map['battery'] as int?,
      batteryState: map['batteryState'] as int?,
      batLevel: map['batLevel'] as int?,
      batteryPercent: map['batteryPercent'] as int?,
      batteryStatus: map['batteryStatus'] as int?,
      samplingRate: map['samplingRate'] as int?,
      mvConversion: (map['mvConversion'] is num)
          ? (map['mvConversion'] as num).toDouble()
          : null,
    );
  }

  @override
  String toString() =>
      'LepuMeasurementEvent($deviceType/$deviceFamily, model=$model, '
      'hr=$hr, spo2=$spo2, pr=$pr, sys=$sys, dia=$dia)';
}

/// Real-time waveform data from a connected device.
class LepuWaveformEvent {
  final String deviceType;
  final String deviceFamily;
  final int model;
  final String? waveType;

  /// ECG float samples (mV)
  final List<double>? ecgFloats;

  /// ECG short samples (raw ADC)
  final List<int>? ecgShorts;

  /// Waveform integer data (oximeter pleth)
  final List<int>? waveData;

  /// PPG IR data
  final List<int>? ir;

  /// PPG Red data
  final List<int>? red;

  /// Sampling rate
  final int? samplingRate;

  /// mV conversion factor for ECG
  final double? mvConversion;

  const LepuWaveformEvent({
    required this.deviceType,
    required this.deviceFamily,
    required this.model,
    this.waveType,
    this.ecgFloats,
    this.ecgShorts,
    this.waveData,
    this.ir,
    this.red,
    this.samplingRate,
    this.mvConversion,
  });

  factory LepuWaveformEvent.fromMap(Map<String, dynamic> map) {
    return LepuWaveformEvent(
      deviceType: (map['deviceType'] as String?) ?? 'unknown',
      deviceFamily: (map['deviceFamily'] as String?) ?? 'unknown',
      model: (map['model'] as int?) ?? -1,
      waveType: map['waveType'] as String?,
      ecgFloats: (map['ecgFloats'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      ecgShorts: (map['ecgShorts'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      waveData: (map['waveData'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      ir: (map['ir'] as List?)?.map((e) => (e as num).toInt()).toList(),
      red: (map['red'] as List?)?.map((e) => (e as num).toInt()).toList(),
      samplingRate: map['samplingRate'] as int?,
      mvConversion: (map['mvConversion'] is num)
          ? (map['mvConversion'] as num).toDouble()
          : null,
    );
  }

  @override
  String toString() =>
      'LepuWaveformEvent($deviceType/$deviceFamily, model=$model, '
      'type=$waveType, samples=${ecgFloats?.length ?? waveData?.length ?? 0})';
}
