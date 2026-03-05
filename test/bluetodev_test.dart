// This is a basic test file for the bluetodev plugin.
// Add actual tests as needed.
import 'package:flutter_test/flutter_test.dart';
import 'package:bluetodev/bluetodev.dart';

void main() {
  test('DeviceModels contains ECG models', () {
    expect(DeviceModels.allEcg.isNotEmpty, true);
  });

  test('DeviceModels contains oximeter models', () {
    expect(DeviceModels.allOximeter.isNotEmpty, true);
  });

  test('DeviceModels contains BP models', () {
    expect(DeviceModels.allBp.isNotEmpty, true);
  });

  test('LepuDeviceInfo fromMap works', () {
    final map = {
      'name': 'ER2-S',
      'mac': 'AA:BB:CC:DD:EE:FF',
      'model': 14,
      'rssi': -55,
    };
    final device = LepuDeviceInfo.fromMap(map);
    expect(device.name, 'ER2-S');
    expect(device.mac, 'AA:BB:CC:DD:EE:FF');
    expect(device.model, 14);
    expect(device.rssi, -55);
  });

  test('LepuMeasurementEvent fromMap works for ECG', () {
    final map = {
      'event': 'rtData',
      'deviceType': 'ecg',
      'deviceFamily': 'er2',
      'model': 14,
      'hr': 72,
      'battery': 85,
      'batteryState': 0,
      'samplingRate': 125,
      'mvConversion': 0.002467,
    };
    final event = LepuMeasurementEvent.fromMap(map);
    expect(event.deviceType, 'ecg');
    expect(event.hr, 72);
    expect(event.samplingRate, 125);
  });

  test('LepuMeasurementEvent fromMap works for oximeter', () {
    final map = {
      'event': 'rtData',
      'deviceType': 'oximeter',
      'deviceFamily': 'oxy',
      'model': 6,
      'spo2': 98,
      'pr': 68,
      'pi': 5.2,
    };
    final event = LepuMeasurementEvent.fromMap(map);
    expect(event.spo2, 98);
    expect(event.pr, 68);
    expect(event.pi, 5.2);
  });
}
