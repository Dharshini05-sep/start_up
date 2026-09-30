import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/sensor_reading.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/bluetooth_service.dart';
import '../services/ip_sensor_service.dart';
import '../widgets/sensor_card.dart';

enum ConnectionMode {
  bluetooth,
  ipWifi,
}

class DoctorPage extends StatefulWidget {
  final AuthService authService;
  final IStorageService storageService;
  final IBluetoothService bluetoothService;
  final IIpSensorService ipSensorService;

  const DoctorPage({
    super.key,
    required this.authService,
    required this.storageService,
    required this.bluetoothService,
    required this.ipSensorService,
  });

  @override
  State<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage> {
  ConnectionMode _activeMode = ConnectionMode.bluetooth;

  // Controller for manual LoRa / Bluetooth module MAC address
  final _macAddressController = TextEditingController();

  // Controllers for IP connection
  final _ipController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '8080');

  // Active sensor telemetry state
  SensorReading _currentReading = SensorReading.disconnected();
  String _connectionStatus = 'Disconnected';
  String? _statusErrorMessage;

  // Bluetooth states
  List<BluetoothDevice> _bondedDevices = [];
  List<ScanResult> _discoveredDevices = [];
  bool _isScanning = false;
  String? _connectingDeviceId;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  // Subscriptions
  StreamSubscription<String>? _btStatusSub;
  StreamSubscription<List<ScanResult>>? _btScanSub;
  StreamSubscription<List<BluetoothDevice>>? _btBondedSub;
  StreamSubscription<BluetoothAdapterState>? _btAdapterSub;
  StreamSubscription<SensorReading>? _btReadingSub;

  StreamSubscription<String>? _ipStatusSub;
  StreamSubscription<SensorReading>? _ipReadingSub;

  @override
  void initState() {
    super.initState();
    _initSubscriptions();
  }

  void _initSubscriptions() {
    // Adapter state
    _adapterState = widget.bluetoothService.adapterState;
    _btAdapterSub = widget.bluetoothService.adapterStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _adapterState = state;
        });
      }
    });

    // Bluetooth status
    _btStatusSub = widget.bluetoothService.statusStream.listen((status) {
      if (_activeMode == ConnectionMode.bluetooth && mounted) {
        setState(() {
          _connectionStatus = status;
          _isScanning = widget.bluetoothService.isScanning;
          _statusErrorMessage = widget.bluetoothService.lastError;
          if (status == 'Disconnected') {
            _currentReading = SensorReading.disconnected(source: 'Bluetooth');
            _connectingDeviceId = null;
          } else if (status == 'Connected') {
            _connectingDeviceId = null;
          }
        });
      }
    });

    // Bonded / Paired devices from phone
    _btBondedSub = widget.bluetoothService.bondedDevicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _bondedDevices = devices;
        });
      }
    });

    // Bluetooth scan results
    _btScanSub = widget.bluetoothService.scanResultsStream.listen((results) {
      if (mounted) {
        setState(() {
          _discoveredDevices = results;
          _isScanning = widget.bluetoothService.isScanning;
        });
      }
    });

    // Initial load of bonded devices from phone
    widget.bluetoothService.refreshBondedDevices();

    // Bluetooth sensor telemetry
    _btReadingSub = widget.bluetoothService.readingStream.listen((reading) {
      if (_activeMode == ConnectionMode.bluetooth && mounted) {
        setState(() {
          _currentReading = reading;
        });
        _persistReading(reading);
      }
    });

    // IP status
    _ipStatusSub = widget.ipSensorService.statusStream.listen((status) {
      if (_activeMode == ConnectionMode.ipWifi && mounted) {
        setState(() {
          _connectionStatus = status;
          _statusErrorMessage = widget.ipSensorService.lastError;
          if (status == 'Disconnected') {
            _currentReading = SensorReading.disconnected(source: 'IP/Wi-Fi');
          }
        });
      }
    });

    // IP sensor telemetry
    _ipReadingSub = widget.ipSensorService.readingStream.listen((reading) {
      if (_activeMode == ConnectionMode.ipWifi && mounted) {
        setState(() {
          _currentReading = reading;
        });
        _persistReading(reading);
      }
    });
  }

  Future<void> _persistReading(SensorReading reading) async {
    final user = widget.authService.currentUser;
    await widget.storageService.saveSensorReading(
      reading.copyWith(userEmail: user?.email),
      userEmail: user?.email,
    );
  }

  @override
  void dispose() {
    _macAddressController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _btStatusSub?.cancel();
    _btScanSub?.cancel();
    _btBondedSub?.cancel();
    _btAdapterSub?.cancel();
    _btReadingSub?.cancel();
    _ipStatusSub?.cancel();
    _ipReadingSub?.cancel();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the monitoring console?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.bluetoothService.disconnect();
      await widget.ipSensorService.disconnect();
      await widget.authService.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _switchMode(ConnectionMode mode) {
    if (_activeMode == mode) return;
    setState(() {
      _activeMode = mode;
      _connectionStatus = 'Disconnected';
      _statusErrorMessage = null;
      _currentReading = SensorReading.disconnected(
        source: mode == ConnectionMode.bluetooth ? 'Bluetooth' : 'IP/Wi-Fi',
      );
    });
  }

  // Bluetooth Actions
  Future<void> _triggerBluetoothScan() async {
    setState(() {
      _discoveredDevices.clear();
      _statusErrorMessage = null;
      _isScanning = true;
    });
    await widget.bluetoothService.startScan();
    if (mounted) {
      setState(() {
        _isScanning = widget.bluetoothService.isScanning;
      });
    }
  }

  Future<void> _stopBluetoothScan() async {
    await widget.bluetoothService.stopScan();
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _turnOnBluetooth() async {
    final success = await widget.bluetoothService.turnOnBluetooth();
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.bluetoothService.lastError ?? 'Failed to enable Bluetooth on device.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _connectBluetoothDevice(BluetoothDevice device) async {
    setState(() {
      _connectingDeviceId = device.remoteId.str;
      _statusErrorMessage = null;
    });

    final success = await widget.bluetoothService.connect(device);
    if (mounted) {
      setState(() {
        _connectingDeviceId = null;
      });
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.bluetoothService.lastError ?? 'Failed to connect to device.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _connectByMacAddress(String mac) async {
    final cleanMac = mac.trim().toUpperCase();
    if (cleanMac.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid Bluetooth MAC address.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() {
      _connectingDeviceId = cleanMac;
      _connectionStatus = 'Connecting';
      _statusErrorMessage = null;
    });

    final success = await widget.bluetoothService.connectByAddress(cleanMac);
    if (mounted) {
      setState(() {
        _connectingDeviceId = null;
      });
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.bluetoothService.lastError ?? 'Failed to connect to LoRa module ($cleanMac).'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _disconnectBluetooth() async {
    await widget.bluetoothService.disconnect();
    if (mounted) {
      setState(() {
        _connectingDeviceId = null;
      });
    }
  }

  // IP/Wi-Fi Actions
  Future<void> _connectIp() async {
    final ip = _ipController.text.trim();
    final portStr = _portController.text.trim();

    if (!IpSensorService.isValidIp(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid IP address. Example: 192.168.1.100'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (!IpSensorService.isValidPort(portStr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Port must be a valid number between 1 and 65535.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final port = int.parse(portStr);
    final success = await widget.ipSensorService.connect(ip: ip, port: port);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.ipSensorService.lastError ?? 'Failed to connect to sensor.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _disconnectIp() async {
    await widget.ipSensorService.disconnect();
  }

  String _resolveDeviceName(BluetoothDevice device, [AdvertisementData? advData]) {
    if (device.platformName.isNotEmpty) return device.platformName;
    if (advData != null && advData.advName.isNotEmpty) return advData.advName;
    return 'LoRa / Bluetooth Device';
  }

  Widget _buildDeviceSignalIcon(int rssi) {
    if (rssi >= -65) {
      return const Icon(Icons.signal_cellular_alt_rounded, color: Colors.green, size: 20);
    } else if (rssi >= -80) {
      return const Icon(Icons.signal_cellular_alt_2_bar_rounded, color: Colors.orange, size: 20);
    } else {
      return const Icon(Icons.signal_cellular_alt_1_bar_rounded, color: Colors.redAccent, size: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.authService.currentUser;

    // Safety guard: Guardians should use GuardianPage
    if (user?.accountType.toLowerCase() == 'guardian') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/guardian');
        }
      });
    }

    final isConnected = _connectionStatus.toLowerCase() == 'connected';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Doctor Monitoring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (user != null)
              Text(
                '${user.fullName} (${user.accountType})',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SECTION: Connect Sensor
                _buildConnectSensorCard(theme, isConnected),
                const SizedBox(height: 24),

                // SECTION: Sensor Display
                _buildSensorDisplaySection(theme, isConnected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectSensorCard(ThemeData theme, bool isConnected) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.sensors, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Connect Sensor',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Mode Selector: [ Bluetooth ] [ IP/Wi-Fi ]
            SegmentedButton<ConnectionMode>(
              segments: const [
                ButtonSegment<ConnectionMode>(
                  value: ConnectionMode.bluetooth,
                  label: Text('Bluetooth'),
                  icon: Icon(Icons.bluetooth),
                ),
                ButtonSegment<ConnectionMode>(
                  value: ConnectionMode.ipWifi,
                  label: Text('IP/Wi-Fi'),
                  icon: Icon(Icons.wifi),
                ),
              ],
              selected: {_activeMode},
              onSelectionChanged: (Set<ConnectionMode> selected) {
                _switchMode(selected.first);
              },
            ),
            const SizedBox(height: 16),

            // Mode-specific connection content
            if (_activeMode == ConnectionMode.bluetooth)
              _buildBluetoothControls(theme, isConnected)
            else
              _buildIpWifiControls(theme, isConnected),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothControls(ThemeData theme, bool isConnected) {
    final connectedBtDevice = widget.bluetoothService.connectedDevice;
    final isAdapterOff = _adapterState == BluetoothAdapterState.off;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Bluetooth Adapter Off Warning Banner
        if (isAdapterOff) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.bluetooth_disabled_rounded, color: Colors.amber.shade900, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bluetooth is turned off',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                      Text(
                        'Turn on Bluetooth to connect with LoRa modules and sensors.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _turnOnBluetooth,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade200,
                    foregroundColor: Colors.amber.shade900,
                  ),
                  child: const Text('Turn On'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 2. Currently Connected Device Banner
        if (isConnected && connectedBtDevice != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bluetooth_connected_rounded, color: Colors.green, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resolveDeviceName(connectedBtDevice),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        connectedBtDevice.remoteId.str,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Connected & Streaming Telemetry',
                            style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _disconnectBluetooth,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Disconnect'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 3. Paired Devices (Phone Bluetooth) Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone_android_rounded, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Paired Devices (${_bondedDevices.length})',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh Paired Devices',
                    onPressed: () => widget.bluetoothService.refreshBondedDevices(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const Divider(height: 12),
              if (_bondedDevices.isNotEmpty) ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _bondedDevices.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final device = _bondedDevices[index];
                    final isThisConnected = connectedBtDevice?.remoteId == device.remoteId;
                    final isThisConnecting = _connectingDeviceId == device.remoteId.str;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        child: Icon(Icons.bluetooth_rounded, color: theme.colorScheme.primary, size: 18),
                      ),
                      title: Text(
                        _resolveDeviceName(device),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${device.remoteId.str} • Paired on phone',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      trailing: isThisConnected
                          ? const Chip(
                              label: Text('Connected', style: TextStyle(fontSize: 11, color: Colors.green)),
                              side: BorderSide(color: Colors.green),
                              padding: EdgeInsets.zero,
                            )
                          : isThisConnecting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : FilledButton.tonal(
                                  onPressed: _connectionStatus == 'Connecting'
                                      ? null
                                      : () => _connectBluetoothDevice(device),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Connect', style: TextStyle(fontSize: 12)),
                                ),
                    );
                  },
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No paired devices found on phone. You can pair your LoRa module in your phone\'s Bluetooth settings or scan nearby devices below.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Available / Discovered Nearby Devices Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radar_rounded, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Available Devices (${_discoveredDevices.length})',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _isScanning ? _stopBluetoothScan : _triggerBluetoothScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded, size: 16),
                    label: Text(_isScanning ? 'Stop Scan' : 'Scan Devices'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (_isScanning) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const Divider(height: 16),
              if (_discoveredDevices.isNotEmpty) ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _discoveredDevices.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _discoveredDevices[index];
                    final device = result.device;
                    final isThisConnected = connectedBtDevice?.remoteId == device.remoteId;
                    final isThisConnecting = _connectingDeviceId == device.remoteId.str;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.shade50,
                        child: _buildDeviceSignalIcon(result.rssi),
                      ),
                      title: Text(
                        _resolveDeviceName(device, result.advertisementData),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${device.remoteId.str} • ${result.rssi} dBm',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: isThisConnected
                          ? const Chip(
                              label: Text('Connected', style: TextStyle(fontSize: 11, color: Colors.green)),
                              side: BorderSide(color: Colors.green),
                              padding: EdgeInsets.zero,
                            )
                          : isThisConnecting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : ElevatedButton(
                                  onPressed: _connectionStatus == 'Connecting'
                                      ? null
                                      : () => _connectBluetoothDevice(device),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Connect', style: TextStyle(fontSize: 12)),
                                ),
                    );
                  },
                ),
              ] else if (!_isScanning && !isConnected) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  child: Column(
                    children: [
                      Icon(Icons.bluetooth_searching_rounded, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'No Bluetooth devices discovered yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Make sure your LoRa module or Bluetooth device is powered on and within range, then tap "Scan Devices".',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Direct Connect via MAC Address (Collapsible option)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.dialpad_rounded, size: 20, color: Color(0xFF0F766E)),
              title: const Text(
                'Connect Manually by MAC Address (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              subtitle: const Text(
                'Directly target any LoRa module or unadvertised device',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _macAddressController,
                          enabled: !isConnected && _connectionStatus != 'Connecting',
                          decoration: const InputDecoration(
                            labelText: 'Bluetooth MAC Address',
                            hintText: 'e.g. 58:BF:25:EE:FF:F2',
                            prefixIcon: Icon(Icons.settings_bluetooth_rounded, size: 20),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: isConnected || _connectionStatus == 'Connecting'
                            ? null
                            : () => _connectByMacAddress(_macAddressController.text),
                        icon: _connectingDeviceId == _macAddressController.text.trim().toUpperCase()
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.bolt, size: 18),
                        label: const Text('Connect'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIpWifiControls(ThemeData theme, bool isConnected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _ipController,
                enabled: !isConnected,
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  hintText: '192.168.1.100',
                  prefixIcon: Icon(Icons.lan_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.datetime,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _portController,
                enabled: !isConnected,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '8080',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!isConnected)
          FilledButton.icon(
            onPressed: _connectionStatus == 'Connecting' ? null : _connectIp,
            icon: _connectionStatus == 'Connecting'
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.link),
            label: Text(_connectionStatus == 'Connecting' ? 'Connecting...' : 'Connect'),
          )
        else
          OutlinedButton.icon(
            onPressed: _disconnectIp,
            icon: const Icon(Icons.link_off, color: Colors.red),
            label: const Text('Disconnect', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildSensorDisplaySection(ThemeData theme, bool isConnected) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Temperature and Humidity Cards
            Row(
              children: [
                SensorCard(
                  type: SensorType.temperature,
                  value: _currentReading.temperature,
                  isConnected: isConnected && _currentReading.temperature != null,
                ),
                const SizedBox(width: 16),
                SensorCard(
                  type: SensorType.humidity,
                  value: _currentReading.humidity,
                  isConnected: isConnected && _currentReading.humidity != null,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Status display
            _buildStatusCard(theme),

            if (_currentReading.timestamp != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last Reading: ${_currentReading.formattedTimestamp}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    Color statusBg;
    Color statusFg;
    IconData statusIcon;

    switch (_connectionStatus.toLowerCase()) {
      case 'connected':
        statusBg = Colors.green.shade50;
        statusFg = Colors.green.shade800;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'scanning':
        statusBg = Colors.blue.shade50;
        statusFg = Colors.blue.shade800;
        statusIcon = Icons.radar_rounded;
        break;
      case 'connecting':
        statusBg = Colors.amber.shade50;
        statusFg = Colors.amber.shade900;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'connection error':
        statusBg = Colors.red.shade50;
        statusFg = Colors.red.shade800;
        statusIcon = Icons.error_outline_rounded;
        break;
      case 'disconnected':
      default:
        statusBg = Colors.grey.shade100;
        statusFg = Colors.grey.shade700;
        statusIcon = Icons.circle_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusFg.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, size: 18, color: statusFg),
              const SizedBox(width: 8),
              Text(
                'Status: $_connectionStatus',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusFg,
                ),
              ),
            ],
          ),
          if (_statusErrorMessage != null && _connectionStatus == 'Connection Error') ...[
            const SizedBox(height: 6),
            Text(
              _statusErrorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }
}
