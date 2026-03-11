import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bluetodev/bluetodev.dart';
import '../models/saved_device.dart';
import '../services/device_storage_service.dart';

/// Full-screen page for scanning, selecting, and saving a new BLE device.
class AddDevicePage extends StatefulWidget {
  const AddDevicePage({super.key});

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage>
    with SingleTickerProviderStateMixin {
  bool _scanning = false;
  bool _connecting = false;
  String? _connectingMac;
  final List<LepuDeviceInfo> _devices = [];
  StreamSubscription? _eventSub;
  StreamSubscription? _lescaleEventSub;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _listenEvents();
    _startScan();
  }

  void _listenEvents() {
    void handleEvent(Map<String, dynamic> event) {
      final type = event['event'] as String?;
      if (type == 'deviceFound') {
        final device = LepuDeviceInfo.fromMap(event);
        setState(() {
          final existingIdx = _devices.indexWhere((d) => d.mac == device.mac);
          if (existingIdx >= 0) {
            if (device.sdk == 'icomon' && _devices[existingIdx].sdk == 'lescale') {
              _devices[existingIdx] = device;
            }
          } else {
            _devices.add(device);
          }
        });
      } else if (type == 'connectionState') {
        final state = event['state'] as String?;
        if (state == 'connected' && _connectingMac != null) {
          _onDeviceConnected();
        } else if (state == 'disconnected' && _connecting) {
          setState(() {
            _connecting = false;
            _connectingMac = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection failed. Try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    _eventSub = BluetodevController.eventStream.listen(handleEvent);
    _lescaleEventSub = LescaleController.eventStream.listen(handleEvent);
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _devices.clear();
    });
    await Future.wait([BluetodevController.scan(), LescaleController.scan()]);
  }

  Future<void> _stopScan() async {
    await BluetodevController.stopScan();
    await LescaleController.stopScan();
    setState(() => _scanning = false);
  }

  Future<void> _connectAndSave(LepuDeviceInfo device) async {
    setState(() {
      _connecting = true;
      _connectingMac = device.mac;
    });
    await _stopScan();

    if (device.sdk == 'icomon') {
      await BluetodevController.connect(mac: device.mac, sdk: 'icomon');
    } else if (device.model == 9999) {
      await LescaleController.connect(device.mac);
    } else {
      await BluetodevController.connect(model: device.model, mac: device.mac);
    }

    // For iComon/lescale scales, connection is instant via addDevice
    // so we save immediately
    if (device.sdk == 'icomon' || device.model == 9999) {
      await _saveAndReturn(device);
    }
    // For Lepu devices, the connectionState event will trigger _onDeviceConnected
  }

  Future<void> _onDeviceConnected() async {
    final device = _devices.firstWhere(
      (d) => d.mac == _connectingMac,
      orElse: () => LepuDeviceInfo(
        name: 'Unknown',
        mac: _connectingMac!,
        model: -1,
        rssi: 0,
      ),
    );
    await _saveAndReturn(device);
  }

  Future<void> _saveAndReturn(LepuDeviceInfo device) async {
    final saved = SavedDevice(
      mac: device.mac,
      name: device.name.isNotEmpty ? device.name : 'Unknown Device',
      sdk: device.sdk,
      model: device.model,
      deviceType: device.deviceType,
    );
    await DeviceStorageService.saveDevice(saved);

    setState(() {
      _connecting = false;
      _connectingMac = null;
    });

    if (mounted) {
      // Disconnect after saving so device is free for later
      if (device.sdk != 'icomon' && device.model != 9999) {
        await BluetodevController.disconnect();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${saved.name} saved!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop(saved);
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _lescaleEventSub?.cancel();
    _pulseController.dispose();
    _stopScan();
    super.dispose();
  }

  IconData _iconForType(String deviceType) {
    switch (deviceType) {
      case 'ecg':
        return Icons.monitor_heart;
      case 'oximeter':
        return Icons.air;
      case 'bp':
        return Icons.favorite;
      case 'scale':
        return Icons.scale;
      default:
        return Icons.bluetooth;
    }
  }

  Color _colorForType(String deviceType) {
    switch (deviceType) {
      case 'ecg':
        return const Color(0xFFFF5252);
      case 'oximeter':
        return const Color(0xFF448AFF);
      case 'bp':
        return const Color(0xFFFF4081);
      case 'scale':
        return const Color(0xFF69F0AE);
      default:
        return const Color(0xFF90A4AE);
    }
  }

  String _labelForSdk(String sdk) {
    switch (sdk) {
      case 'icomon':
        return 'iComon';
      case 'lescale':
        return 'Lescale';
      case 'lepu':
        return 'Lepu';
      default:
        return sdk;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Add Device'),
        backgroundColor: cs.surface,
        actions: [
          if (_scanning)
            IconButton(
              onPressed: _stopScan,
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: 'Stop Scan',
            )
          else
            IconButton(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh),
              tooltip: 'Rescan',
            ),
        ],
      ),
      body: Column(
        children: [
          // Scanning indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _scanning ? 80 : 0,
            child: _scanning
                ? Center(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                  cs.primary.withValues(
                                    alpha: 0.5 + _pulseController.value * 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scanning for devices...',
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Device list
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 64,
                          color: cs.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _scanning
                              ? 'Looking for nearby devices...'
                              : 'No devices found',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                        ),
                        if (!_scanning) ...[
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: _startScan,
                            child: const Text('Scan Again'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final d = _devices[i];
                      final isConnecting = _connectingMac == d.mac;
                      final typeColor = _colorForType(d.deviceType);

                      return AnimatedOpacity(
                        opacity: _connecting && !isConnecting ? 0.4 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          elevation: isConnecting ? 4 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: isConnecting
                                ? BorderSide(color: cs.primary, width: 2)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: _connecting
                                ? null
                                : () => _connectAndSave(d),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Device type icon
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      _iconForType(d.deviceType),
                                      color: typeColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Device info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.name.isEmpty
                                              ? 'Unknown Device'
                                              : d.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              d.mac,
                                              style: TextStyle(
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.5),
                                                fontSize: 12,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: typeColor
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _labelForSdk(d.sdk),
                                                style: TextStyle(
                                                  color: typeColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Signal + action
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.signal_cellular_alt,
                                            size: 14,
                                            color: d.rssi > -60
                                                ? Colors.green
                                                : d.rssi > -80
                                                    ? Colors.orange
                                                    : Colors.red,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${d.rssi}',
                                            style: TextStyle(
                                              color: cs.onSurface
                                                  .withValues(alpha: 0.4),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (isConnecting)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        Icon(
                                          Icons.add_circle_outline,
                                          color: cs.primary,
                                          size: 22,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
