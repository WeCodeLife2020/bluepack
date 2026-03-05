import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bluetodev/bluetodev.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetodev Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const BleHomePage(),
    );
  }
}

class BleHomePage extends StatefulWidget {
  const BleHomePage({super.key});

  @override
  State<BleHomePage> createState() => _BleHomePageState();
}

class _BleHomePageState extends State<BleHomePage> {
  bool _serviceReady = false;
  bool _scanning = false;
  bool _connected = false;
  String _status = 'Not initialized';
  final List<LepuDeviceInfo> _devices = [];
  LepuDeviceInfo? _connectedDevice;
  String _lastData = '';
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _listenEvents();
  }

  void _listenEvents() {
    _eventSub = BluetodevController.eventStream.listen((event) {
      final type = event['event'] as String?;
      switch (type) {
        case 'serviceReady':
          setState(() {
            _serviceReady = true;
            _status = 'Service ready';
          });
          break;
        case 'deviceFound':
          final device = LepuDeviceInfo.fromMap(event);
          setState(() {
            if (!_devices.any((d) => d.mac == device.mac)) {
              _devices.add(device);
            }
          });
          break;
        case 'connectionState':
          final state = event['state'] as String?;
          setState(() {
            _connected = state == 'connected';
            _status = state == 'connected'
                ? 'Connected (model: ${event['model']})'
                : 'Disconnected (${event['reason'] ?? 'unknown'})';
          });
          break;
        case 'rtData':
          setState(() {
            final dt = event['deviceType'] as String?;
            if (dt == 'ecg') {
              _lastData =
                  'ECG — HR: ${event['hr']} bpm, '
                  'Battery: ${event['battery']}%, '
                  'Status: ${event['curStatus']}';
            } else if (dt == 'oximeter') {
              _lastData =
                  'SpO2: ${event['spo2']}%, '
                  'PR: ${event['pr']} bpm, '
                  'PI: ${event['pi']}';
            } else if (dt == 'bp') {
              final mt = event['measureType'] as String?;
              if (mt == 'bp_result') {
                _lastData =
                    'BP: ${event['sys']}/${event['dia']} mmHg, '
                    'PR: ${event['pr']} bpm';
              } else if (mt == 'bp_measuring') {
                _lastData = 'Pressure: ${event['pressure']} mmHg';
              } else {
                _lastData = 'ECG(BP) — HR: ${event['hr']} bpm';
              }
            }
          });
          break;
      }
    });
  }

  Future<void> _init() async {
    setState(() => _status = 'Requesting permissions...');
    final granted = await BluetodevController.requestPermissions();
    if (!granted) {
      setState(() => _status = 'Permissions denied');
      return;
    }
    setState(() => _status = 'Initializing service...');
    await BluetodevController.initService();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _devices.clear();
      _status = 'Scanning...';
    });
    await BluetodevController.scan();
  }

  Future<void> _stopScan() async {
    await BluetodevController.stopScan();
    setState(() {
      _scanning = false;
      _status = 'Scan stopped (${_devices.length} devices)';
    });
  }

  Future<void> _connect(LepuDeviceInfo device) async {
    setState(() => _status = 'Connecting to ${device.name}...');
    await BluetodevController.stopScan();
    await BluetodevController.connect(model: device.model, mac: device.mac);
    _connectedDevice = device;
  }

  Future<void> _disconnect() async {
    await BluetodevController.stopMeasurement();
    await BluetodevController.disconnect();
    setState(() {
      _connected = false;
      _connectedDevice = null;
      _lastData = '';
    });
  }

  Future<void> _startMeasurement() async {
    await BluetodevController.startMeasurement();
    setState(() => _status = 'Measuring...');
  }

  Future<void> _stopMeasurement() async {
    await BluetodevController.stopMeasurement();
    setState(() => _status = 'Measurement stopped');
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetodev — BLE Plugin'),
        backgroundColor: cs.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(_status, style: const TextStyle(fontSize: 14)),
                    if (_lastData.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _lastData,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!_serviceReady)
                  FilledButton.icon(
                    onPressed: _init,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Initialize'),
                  ),
                if (_serviceReady && !_connected) ...[
                  FilledButton.icon(
                    onPressed: _scanning ? _stopScan : _startScan,
                    icon: Icon(_scanning ? Icons.stop : Icons.search),
                    label: Text(_scanning ? 'Stop Scan' : 'Scan'),
                  ),
                ],
                if (_connected) ...[
                  FilledButton.icon(
                    onPressed: _startMeasurement,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start RT'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _stopMeasurement,
                    icon: const Icon(Icons.pause),
                    label: const Text('Stop RT'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _disconnect,
                    icon: const Icon(Icons.bluetooth_disabled),
                    label: const Text('Disconnect'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Device list
            if (!_connected)
              Expanded(
                child: _devices.isEmpty
                    ? const Center(child: Text('No devices found'))
                    : ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (ctx, i) {
                          final d = _devices[i];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                d.deviceType == 'ecg'
                                    ? Icons.monitor_heart
                                    : d.deviceType == 'oximeter'
                                    ? Icons.air
                                    : d.deviceType == 'bp'
                                    ? Icons.favorite
                                    : Icons.bluetooth,
                                color: cs.primary,
                              ),
                              title: Text(d.name.isEmpty ? 'Unknown' : d.name),
                              subtitle: Text(
                                '${d.mac} • model ${d.model} • ${d.rssi} dBm',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _connect(d),
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
