import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class LescaleDebugScreen extends StatefulWidget {
  const LescaleDebugScreen({super.key});

  @override
  State<LescaleDebugScreen> createState() => _LescaleDebugScreenState();
}

class _LescaleDebugScreenState extends State<LescaleDebugScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];
  String _logBuffer = '';

  @override
  void initState() {
    super.initState();
    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        _scanResults = results.where((r) {
          final name = r.device.platformName.toLowerCase();
          final advName = r.advertisementData.advName.toLowerCase();
          return name.contains('lescale') ||
              name.contains('fi2016') ||
              advName.contains('lescale') ||
              advName.contains('fi2016') ||
              name.isNotEmpty; // show other named devices if needed, but lets just show everything for now to be safe
        }).toList();
      });
    });

    FlutterBluePlus.isScanning.listen((isScanning) {
      if (!mounted) return;
      setState(() {
        _isScanning = isScanning;
      });
    });
  }

  void _log(String message) {
    if (!mounted) return;
    setState(() {
      _logBuffer = '$message\n$_logBuffer';
    });
    print(message);
  }

  Future<void> _startScan() async {
    _scanResults.clear();
    _log('Starting scan...');
    try {
      await FlutterBluePlus.adapterState
          .where((val) => val == BluetoothAdapterState.on)
          .first;
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      _log('Scan Error: $e');
    }
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    _log('Scan stopped');
  }

  Future<void> _connect(BluetoothDevice device) async {
    await _stopScan();
    try {
      _log('Connecting to ${device.platformName}...');
      await device.connect();
      _log('Connected!');
      setState(() {
        _connectedDevice = device;
      });

      _log('Discovering services...');
      List<BluetoothService> services = await device.discoverServices();
      setState(() {
        _services = services;
      });
      _log('Found ${services.length} services');

      // Subscribe to all notifications just to sniff
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            _log('Subscribing to ${characteristic.uuid}...');
            try {
              if (characteristic.isNotifying == false) {
                await characteristic.setNotifyValue(true);
              }
              characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  final hexStr = value
                      .map((b) => b.toRadixString(16).padLeft(2, '0'))
                      .join(' ');
                  _log('[NOTIFY] ${characteristic.uuid}: $hexStr');
                }
              });
            } catch (e) {
              _log('Failed to subscribe ${characteristic.uuid}: $e');
            }
          }
        }
      }
    } catch (e) {
      _log('Connect Error: $e');
    }
  }

  Future<void> _disconnect() async {
    if (_connectedDevice != null) {
      _log('Disconnecting...');
      await _connectedDevice!.disconnect();
      setState(() {
        _connectedDevice = null;
        _services = [];
      });
      _log('Disconnected');
    }
  }

  @override
  void dispose() {
    _stopScan();
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lescale / FI2016LB Debugger')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isScanning ? null : _startScan,
                child: const Text('Start Scan'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isScanning ? _stopScan : null,
                child: const Text('Stop Scan'),
              ),
              const SizedBox(width: 10),
              if (_connectedDevice != null)
                ElevatedButton(
                  onPressed: _disconnect,
                  child: const Text('Disconnect'),
                ),
            ],
          ),
          const Divider(),
          if (_connectedDevice == null)
            Expanded(
              flex: 1,
              child: ListView.builder(
                itemCount: _scanResults.length,
                itemBuilder: (context, index) {
                  final r = _scanResults[index];
                  final name = r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : r.advertisementData.advName;
                  return ListTile(
                    title: Text(name.isNotEmpty ? name : 'Unknown Device'),
                    subtitle: Text('${r.device.remoteId} • ${r.rssi} dBm'),
                    trailing: ElevatedButton(
                      onPressed: () => _connect(r.device),
                      child: const Text('Connect'),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black87,
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Text(
                  _logBuffer,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
