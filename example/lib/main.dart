import 'dart:async';
import 'dart:math' show pow;
import 'package:flutter/material.dart';
import 'package:bluetodev/bluetodev.dart';
import 'models/saved_device.dart';
import 'models/user_profile.dart';
import 'models/scale_reading.dart';
import 'services/device_storage_service.dart';
import 'services/reading_history_service.dart';
import 'pages/add_device_page.dart';
import 'pages/user_profile_page.dart';
import 'pages/scale_history_page.dart';
import 'lescale_debug_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetodev Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _serviceReady = false;
  bool _connected = false;
  String _status = 'Not initialized';
  String _lastData = '';
  SavedDevice? _connectedDevice;
  List<SavedDevice> _savedDevices = [];
  StreamSubscription? _eventSub;
  StreamSubscription? _lescaleEventSub;
  UserProfile? _profile;

  // Profile defaults (updated from saved profile)
  double _heightCm = 170.0;
  int _age = 25;
  bool _isMale = true;

  @override
  void initState() {
    super.initState();
    _loadSavedDevices();
    _loadProfile();
    _listenEvents();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfile.load();
    if (profile != null && mounted) {
      setState(() {
        _profile = profile;
        _heightCm = profile.heightCm;
        _age = profile.age;
        _isMale = profile.isMale;
      });
    }
  }

  Future<void> _loadSavedDevices() async {
    final devices = await DeviceStorageService.loadDevices();
    setState(() => _savedDevices = devices);
  }

  void _listenEvents() {
    void handleEvent(Map<String, dynamic> event) {
      final type = event['event'] as String?;
      switch (type) {
        case 'serviceReady':
          setState(() {
            _serviceReady = true;
            _status = 'Service ready';
          });
          break;
        case 'connectionState':
          final state = event['state'] as String?;
          setState(() {
            _connected = state == 'connected';
            _status = state == 'connected'
                ? 'Connected to ${_connectedDevice?.name ?? 'device'}'
                : 'Disconnected';
          });
          break;
        case 'rtData':
          _handleRtData(event);
          break;
      }
    }

    _eventSub = BluetodevController.eventStream.listen(handleEvent);
    _lescaleEventSub = LescaleController.eventStream.listen(handleEvent);
  }

  void _handleRtData(Map<String, dynamic> event) {
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
      } else if (dt == 'scale') {
        final locked = event['isLocked'] == true;
        final weight = event['weightKg'];
        final hr = event['heartRate'];
        final fat = event['fat'];
        final fatMass = event['fat_mass'];
        final muscle = event['muscle'];
        final skeletalMuscle = event['skeletal_muscle'];
        final bmi = event['bmi'];
        final water = event['water'];
        final bone = event['bone'];
        final protein = event['protein'];
        final bmr = event['bmr'];
        final visceral = event['visceral'];
        final subcutaneous = event['subcutaneous'];
        final bodyAge = event['body_age'];

        // Calculate Cardiac Index: CI = CO / BSA
        // CO = HR × SV(70ml) / 1000,  BSA = 0.007184 × H^0.725 × W^0.425
        String ciStr = '--';
        if (hr != null && hr is num && hr > 0 && weight is num && weight > 0) {
          final w = weight.toDouble();
          final h = _heightCm;
          final bsa = 0.007184 * pow(h, 0.725) * pow(w, 0.425);
          if (bsa > 0) {
            final co = hr.toDouble() * 70.0 / 1000.0;
            final ci = co / bsa;
            ciStr = ci.toStringAsFixed(1);
          }
        }

        String details = 'Scale — Weight: $weight kg';
        if (bmi != null) details += '\nBMI: $bmi • HR: $hr bpm';
        if (fat != null) details += '\nBody Fat: $fat% • Fat Mass: $fatMass kg';
        if (water != null) details += '\nBody Water: $water%';
        if (bmr != null) details += '\nBMR: $bmr kcal • Protein: $protein%';
        if (skeletalMuscle != null) details += '\nSkeletal Muscle: $skeletalMuscle kg';
        if (muscle != null) details += '\nMuscle Mass: $muscle kg';
        if (bone != null) details += ' • Bone Mass: $bone kg';
        if (visceral != null)
          details += '\nVisceral Fat: $visceral • Subcut. Fat: $subcutaneous%';
        if (bodyAge != null) details += '\nBody Age: $bodyAge • CI: $ciStr';

        if (!locked) {
          _status = 'Measuring... Stand still';
          _lastData = details;
        } else {
          _status = 'BIA Complete';
          _lastData = details;
          // Save to history
          final reading = ScaleReading.fromEvent(
            event,
            heightCm: _heightCm,
            deviceName: _connectedDevice?.name ?? '',
          );
          ReadingHistoryService.addScaleReading(reading);
          print('═══ SCALE MEASUREMENT COMPLETE ═══');
          print(details);
          print('─── Raw Event Data ───');
          event.forEach((k, v) => print('  $k: $v'));
          print('  CI (calculated): $ciStr');
          print('══════════════════════════════════');
        }
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

  Future<void> _connectToSaved(SavedDevice device) async {
    setState(() {
      _status = 'Connecting to ${device.name}...';
      _connectedDevice = device;
    });

    if (device.sdk == 'icomon') {
      await BluetodevController.updateUserInfo(
        height: _heightCm,
        age: _age,
        isMale: _isMale,
      );
      await BluetodevController.connect(mac: device.mac, sdk: 'icomon');
    } else if (device.sdk == 'lescale' || device.model == 9999) {
      await LescaleController.connect(device.mac);
    } else {
      await BluetodevController.connect(model: device.model, mac: device.mac);
    }
  }

  Future<void> _disconnect() async {
    if (_connectedDevice?.sdk == 'icomon') {
      await BluetodevController.disconnect();
    } else if (_connectedDevice?.sdk == 'lescale' ||
        _connectedDevice?.model == 9999) {
      await LescaleController.disconnect();
    } else {
      await BluetodevController.stopMeasurement();
      await BluetodevController.disconnect();
    }
    setState(() {
      _connected = false;
      _connectedDevice = null;
      _lastData = '';
      _status = 'Disconnected';
    });
  }

  Future<void> _startMeasurement() async {
    if (_connectedDevice?.sdk == 'icomon' ||
        _connectedDevice?.sdk == 'lescale' ||
        _connectedDevice?.model == 9999) {
      setState(() {
        _status = 'Measuring... (Step on the scale)';
        _lastData = '';
      });
      return;
    }
    await BluetodevController.startMeasurement();
    setState(() => _status = 'Measuring...');
  }

  Future<void> _stopMeasurement() async {
    if (_connectedDevice?.sdk == 'icomon' ||
        _connectedDevice?.sdk == 'lescale' ||
        _connectedDevice?.model == 9999) {
      setState(() => _status = 'Measurement paused');
      return;
    }
    await BluetodevController.stopMeasurement();
    setState(() => _status = 'Measurement stopped');
  }

  Future<void> _removeSavedDevice(SavedDevice device) async {
    await DeviceStorageService.removeDevice(device.mac);
    await _loadSavedDevices();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${device.name} removed')),
      );
    }
  }

  void _openAddDevice() async {
    if (!_serviceReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Initialize service first')),
      );
      return;
    }
    final result = await Navigator.push<SavedDevice>(
      context,
      MaterialPageRoute(builder: (_) => const AddDevicePage()),
    );
    if (result != null) {
      await _loadSavedDevices();
    }
  }

  void _openEditProfile() async {
    final result = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(builder: (_) => const UserProfilePage()),
    );
    if (result != null) {
      setState(() {
        _profile = result;
        _heightCm = result.heightCm;
        _age = result.age;
        _isMale = result.isMale;
      });
      _updateProfile();
    }
  }

  void _updateProfile() {
    LescaleController.setProfile(
      heightCm: _heightCm,
      age: _age,
      isMale: _isMale,
    );
    BluetodevController.updateUserInfo(
      height: _heightCm,
      age: _age,
      isMale: _isMale,
    );
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _lescaleEventSub?.cancel();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  IconData _iconForType(String type) {
    switch (type) {
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

  Color _colorForType(String type) {
    switch (type) {
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

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Bluetodev'),
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScaleHistoryPage()),
            ),
            icon: const Icon(Icons.history, size: 22),
            tooltip: 'History',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LescaleDebugScreen()),
            ),
            icon: const Icon(Icons.bug_report, size: 20),
            tooltip: 'Debug',
          ),
        ],
      ),
      floatingActionButton: _serviceReady && !_connected
          ? FloatingActionButton.extended(
              onPressed: _openAddDevice,
              icon: const Icon(Icons.add),
              label: const Text('Add Device'),
            )
          : null,
      body: _profile == null
          ? _buildFirstTimeSetup(cs)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Init button ──
                  if (!_serviceReady)
                    FilledButton.icon(
                      onPressed: _init,
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text('Initialize BLE Service'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),

                  // ── Status card ──
                  if (_serviceReady) ...[
                    _buildStatusCard(cs),
                    const SizedBox(height: 16),
                  ],

                  // ── Connected actions ──
                  if (_connected) ...[
                    _buildConnectedActions(cs),
                    const SizedBox(height: 16),
                  ],

                  // ── Saved Devices ──
                  if (_serviceReady && !_connected) ...[
                    _buildSavedDevicesList(cs),
                    const SizedBox(height: 16),
                  ],

                  // ── Profile summary ──
                  if (_serviceReady) _buildProfileSummary(cs),

                  const SizedBox(height: 80), // FAB clearance
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(ColorScheme cs) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _connected ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _connected ? 'Connected' : 'Status',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_status, style: const TextStyle(fontSize: 14)),
            if (_lastData.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _lastData,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedActions(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _startMeasurement,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Start'),
        ),
        FilledButton.tonal(
          onPressed: _stopMeasurement,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause, size: 18),
              SizedBox(width: 6),
              Text('Stop'),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _disconnect,
          icon: const Icon(Icons.bluetooth_disabled, size: 18),
          label: const Text('Disconnect'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade300),
        ),
      ],
    );
  }

  Widget _buildSavedDevicesList(ColorScheme cs) {
    if (_savedDevices.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.devices,
                size: 48,
                color: cs.onSurface.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              Text(
                'No saved devices',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.4),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap "Add Device" to scan and pair',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'My Devices',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        ...List.generate(_savedDevices.length, (i) {
          final d = _savedDevices[i];
          final typeColor = _colorForType(d.deviceType);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _connectToSaved(d),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              d.mac,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.4),
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeSavedDevice(d),
                        icon: Icon(
                          Icons.delete_outline,
                          color: cs.onSurface.withValues(alpha: 0.3),
                          size: 20,
                        ),
                        tooltip: 'Remove',
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFirstTimeSetup(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.waving_hand_rounded,
              size: 64,
              color: cs.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up your profile to get started\nwith accurate health measurements',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurface.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.person_add),
              label: const Text('Set Up Profile'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSummary(ColorScheme cs) {
    final p = _profile;
    if (p == null) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openEditProfile,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primary.withValues(alpha: 0.15),
                child: Text(
                  p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${p.heightCm.round()} cm • ${p.weightKg.round()} kg • ${p.age} yrs • ${p.isMale ? 'Male' : 'Female'}',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
