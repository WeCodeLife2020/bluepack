import 'dart:async';
import 'package:flutter/services.dart';
import 'models/device_info.dart';
import 'models/measurement_event.dart';

/// Main controller for Viatom/Lepu BLE medical devices.
///
/// Usage:
/// ```dart
/// // 1. Request permissions
/// await BluetodevController.requestPermissions();
///
/// // 2. Initialize BLE service
/// await BluetodevController.initService();
///
/// // 3. Listen to events
/// BluetodevController.eventStream.listen((event) { ... });
///
/// // 4. Start scanning
/// await BluetodevController.scan();
///
/// // 5. Connect to a device
/// await BluetodevController.connect(model: device.model, mac: device.mac);
///
/// // 6. Start real-time measurement
/// await BluetodevController.startMeasurement();
/// ```
class BluetodevController {
  BluetodevController._();

  static const MethodChannel _method = MethodChannel('viatom_ble');
  static const EventChannel _event = EventChannel('viatom_ble_stream');

  static Stream<Map<String, dynamic>>? _eventStream;

  // ════════════════════════════════════════════════════════════════════
  // Event stream
  // ════════════════════════════════════════════════════════════════════

  /// Raw event stream from the native SDK.
  ///
  /// Events have an `event` key indicating the type:
  /// - `serviceReady` — BLE service initialized
  /// - `deviceFound` — device discovered during scan
  /// - `connectionState` — connection state changed
  /// - `rtData` — real-time measurement data
  /// - `rtWaveform` — real-time waveform data
  /// - `deviceInfo` — device information response
  /// - `fileList` — file list response
  static Stream<Map<String, dynamic>> get eventStream {
    _eventStream ??= _event.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event as Map),
    );
    return _eventStream!;
  }

  /// Stream of discovered devices during scanning.
  static Stream<LepuDeviceInfo> get scanStream => eventStream
      .where((e) => e['event'] == 'deviceFound')
      .map((e) => LepuDeviceInfo.fromMap(e));

  /// Stream of connection state changes.
  static Stream<Map<String, dynamic>> get connectionStream =>
      eventStream.where((e) => e['event'] == 'connectionState');

  /// Stream of real-time measurement data (vitals).
  static Stream<LepuMeasurementEvent> get measurementStream => eventStream
      .where((e) => e['event'] == 'rtData')
      .map((e) => LepuMeasurementEvent.fromMap(e));

  /// Stream of real-time waveform data (ECG, PPG, pleth).
  static Stream<LepuWaveformEvent> get waveformStream => eventStream
      .where((e) => e['event'] == 'rtWaveform')
      .map((e) => LepuWaveformEvent.fromMap(e));

  /// Stream of device info responses.
  static Stream<Map<String, dynamic>> get deviceInfoStream =>
      eventStream.where((e) => e['event'] == 'deviceInfo');

  /// Stream of file list responses.
  static Stream<Map<String, dynamic>> get fileListStream =>
      eventStream.where((e) => e['event'] == 'fileList');

  // ════════════════════════════════════════════════════════════════════
  // Permissions
  // ════════════════════════════════════════════════════════════════════

  /// Check if BLE permissions are granted.
  static Future<bool> checkPermissions() async {
    final result = await _method.invokeMethod<bool>('checkPermissions');
    return result ?? false;
  }

  /// Request BLE permissions. Returns true if all granted.
  static Future<bool> requestPermissions() async {
    final result = await _method.invokeMethod<bool>('requestPermissions');
    return result ?? false;
  }

  // ════════════════════════════════════════════════════════════════════
  // Service lifecycle
  // ════════════════════════════════════════════════════════════════════

  /// Initialize the BLE service. Must be called before any other method.
  static Future<bool> initService() async {
    final result = await _method.invokeMethod<bool>('initService');
    return result ?? false;
  }

  /// Check if the BLE service is ready.
  static Future<bool> isServiceReady() async {
    final result = await _method.invokeMethod<bool>('isServiceReady');
    return result ?? false;
  }

  /// Update the internal User Profile for scales (iComon)
  static Future<bool> updateUserInfo({
    required double height,
    required int age,
    required bool isMale,
  }) async {
    final result = await _method.invokeMethod<bool>('updateUserInfo', {
      'height': height,
      'age': age,
      'isMale': isMale,
    });
    return result ?? false;
  }

  // ════════════════════════════════════════════════════════════════════
  // Scanning
  // ════════════════════════════════════════════════════════════════════

  /// Start scanning for BLE devices.
  ///
  /// Optionally filter by [models] (Lepu SDK model constants).
  /// If not specified, scans for all supported devices.
  static Future<bool> scan({List<int>? models}) async {
    final result = await _method.invokeMethod<bool>('scan', {
      if (models != null) 'models': models,
    });
    return result ?? false;
  }

  /// Stop scanning.
  static Future<bool> stopScan() async {
    final result = await _method.invokeMethod<bool>('stopScan');
    return result ?? false;
  }

  // ════════════════════════════════════════════════════════════════════
  // Connection
  // ════════════════════════════════════════════════════════════════════

  /// Connect to a device by [mac] address.
  ///
  /// For Lepu devices, [model] is required.
  /// For iComon devices, pass [sdk] = 'icomon'.
  /// The device must first be discovered via [scan].
  static Future<bool> connect({int? model, required String mac, String sdk = 'lepu'}) async {
    final result = await _method.invokeMethod<bool>('connect', {
      if (model != null) 'model': model,
      'mac': mac,
      'sdk': sdk,
    });
    return result ?? false;
  }

  /// Disconnect from the currently connected device.
  static Future<bool> disconnect() async {
    final result = await _method.invokeMethod<bool>('disconnect');
    return result ?? false;
  }

  /// Get the currently connected device model, or -1 if none.
  static Future<int> getConnectedModel() async {
    final result = await _method.invokeMethod<int>('getConnectedModel');
    return result ?? -1;
  }

  // ════════════════════════════════════════════════════════════════════
  // Real-time measurement
  // ════════════════════════════════════════════════════════════════════

  /// Start real-time measurement streaming.
  ///
  /// Optionally specify [model] to start RT task for a specific device.
  static Future<bool> startMeasurement({int? model}) async {
    final result = await _method.invokeMethod<bool>('startMeasurement', {
      if (model != null) 'model': model,
    });
    return result ?? false;
  }

  /// Stop real-time measurement streaming.
  static Future<bool> stopMeasurement({int? model}) async {
    final result = await _method.invokeMethod<bool>('stopMeasurement', {
      if (model != null) 'model': model,
    });
    return result ?? false;
  }

  // ════════════════════════════════════════════════════════════════════
  // Device management
  // ════════════════════════════════════════════════════════════════════

  /// Request device information from the connected device.
  static Future<bool> getDeviceInfo({int? model}) async {
    final result = await _method.invokeMethod<bool>('getDeviceInfo', {
      if (model != null) 'model': model,
    });
    return result ?? false;
  }

  /// Request the file list from the connected device.
  static Future<bool> getFileList({int? model}) async {
    final result = await _method.invokeMethod<bool>('getFileList', {
      if (model != null) 'model': model,
    });
    return result ?? false;
  }

  /// Factory reset the connected device.
  static Future<bool> factoryReset({int? model}) async {
    final result = await _method.invokeMethod<bool>('factoryReset', {
      if (model != null) 'model': model,
    });
    return result ?? false;
  }
}
