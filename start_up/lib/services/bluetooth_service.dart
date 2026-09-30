import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sensor_reading.dart';

abstract class IBluetoothService {
  Stream<String> get statusStream;
  Stream<List<ScanResult>> get scanResultsStream;
  Stream<List<BluetoothDevice>> get bondedDevicesStream;
  Stream<BluetoothAdapterState> get adapterStateStream;
  Stream<SensorReading> get readingStream;

  String get currentStatus;
  String? get lastError;
  BluetoothDevice? get connectedDevice;
  String? get connectingDeviceId;
  bool get isScanning;
  BluetoothAdapterState get adapterState;

  Future<bool> checkAndRequestPermissions();
  Future<bool> turnOnBluetooth();
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)});
  Future<void> stopScan();
  Future<bool> connect(BluetoothDevice device);
  Future<bool> connectByAddress(String macAddress, {String? deviceName});
  Future<List<BluetoothDevice>> getBondedDevices();
  Future<void> refreshBondedDevices();
  Future<void> disconnect();
  void dispose();
}

class BluetoothSensorService implements IBluetoothService {
  // =========================================================================
  // HARDWARE INTEGRATION CONFIGURATION (LoRa / ESP32 Sensor)
  // =========================================================================
  static const String defaultTargetMacAddress = '58:BF:25:EE:FF:F2';
  static const String defaultTargetDeviceName = 'ESP32-BT-Master';
  static const String? targetServiceUuid = null; // Optional: auto-discovers if null
  static const String? targetCharacteristicUuid = null; // Optional: auto-discovers if null
  static const String? deviceNameFilter = null; // Optional filter

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  final StreamController<List<ScanResult>> _scanResultsController =
      StreamController<List<ScanResult>>.broadcast();
  final StreamController<List<BluetoothDevice>> _bondedDevicesController =
      StreamController<List<BluetoothDevice>>.broadcast();
  final StreamController<SensorReading> _readingController =
      StreamController<SensorReading>.broadcast();

  String _currentStatus = 'Disconnected';
  String? _lastError;
  BluetoothDevice? _connectedDevice;
  String? _connectingDeviceId;
  bool _isScanning = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  final List<StreamSubscription<List<int>>> _characteristicSubscriptions = [];

  // Stream packet buffer for chunked BLE messages
  final StringBuffer _rxBuffer = StringBuffer();
  DateTime? _lastRxTime;

  BluetoothSensorService() {
    _initAdapterMonitoring();
  }

  void _initAdapterMonitoring() {
    try {
      FlutterBluePlus.isSupported.then((supported) {
        if (supported) {
          try {
            _adapterState = FlutterBluePlus.adapterStateNow;
            _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
              _adapterState = state;
              if (state == BluetoothAdapterState.off) {
                if (_currentStatus == 'Connected') {
                  disconnect();
                }
                _updateStatus('Disconnected', error: 'Bluetooth is turned off on device.');
              }
            });
          } catch (_) {}
        }
      }).catchError((_) {});
    } catch (_) {}
  }

  @override
  Stream<String> get statusStream => _statusController.stream;

  @override
  Stream<List<ScanResult>> get scanResultsStream =>
      _scanResultsController.stream;

  @override
  Stream<List<BluetoothDevice>> get bondedDevicesStream =>
      _bondedDevicesController.stream;

  @override
  Stream<BluetoothAdapterState> get adapterStateStream {
    try {
      return FlutterBluePlus.adapterState;
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Stream<SensorReading> get readingStream => _readingController.stream;

  @override
  String get currentStatus => _currentStatus;

  @override
  String? get lastError => _lastError;

  @override
  BluetoothDevice? get connectedDevice => _connectedDevice;

  @override
  String? get connectingDeviceId => _connectingDeviceId;

  @override
  bool get isScanning => _isScanning;

  @override
  BluetoothAdapterState get adapterState => _adapterState;

  void _updateStatus(String newStatus, {String? error}) {
    _currentStatus = newStatus;
    _lastError = error;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  @override
  Future<bool> turnOnBluetooth() async {
    try {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
        return true;
      }
    } catch (e) {
      _updateStatus('Connection Error', error: 'Could not enable Bluetooth: ${e.toString()}');
    }
    return false;
  }

  @override
  Future<bool> checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      try {
        final scanStatus = await Permission.bluetoothScan.status;
        final connectStatus = await Permission.bluetoothConnect.status;

        if (scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied) {
          _updateStatus(
            'Connection Error',
            error: 'Bluetooth permissions are permanently denied. Please enable them in device Settings.',
          );
          return false;
        }

        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();

        // If either scan or connect is denied (and not permanently denied)
        if (statuses[Permission.bluetoothScan]?.isDenied == true ||
            statuses[Permission.bluetoothConnect]?.isDenied == true) {
          // Check location permission as fallback for Android <= 11
          final locGranted = await Permission.locationWhenInUse.isGranted ||
              await Permission.location.isGranted;
          if (!locGranted) {
            _updateStatus(
              'Connection Error',
              error: 'Bluetooth and Location permissions are required to scan for sensors.',
            );
            return false;
          }
        }
      } catch (_) {}
    }
    return true;
  }

  @override
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      if (Platform.isAndroid) {
        return await FlutterBluePlus.bondedDevices;
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<void> refreshBondedDevices() async {
    try {
      final bonded = await getBondedDevices();
      if (!_bondedDevicesController.isClosed) {
        _bondedDevicesController.add(bonded);
      }
    } catch (_) {}
  }

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return;

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _updateStatus(
          'Connection Error',
          error: 'Bluetooth is turned off. Please enable Bluetooth to scan for sensors.',
        );
        return;
      }

      _isScanning = true;
      _updateStatus('Scanning');

      // Also refresh paired/bonded devices from phone
      refreshBondedDevices();

      // Listen to scan results from FlutterBluePlus
      _scanResultsSubscription?.cancel();
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        final List<ScanResult> filtered = [];
        for (final r in results) {
          if (deviceNameFilter != null && deviceNameFilter!.isNotEmpty) {
            final matches = r.device.platformName.toLowerCase().contains(deviceNameFilter!.toLowerCase()) ||
                r.advertisementData.advName.toLowerCase().contains(deviceNameFilter!.toLowerCase());
            if (!matches) continue;
          }
          filtered.add(r);
        }

        if (!_scanResultsController.isClosed) {
          _scanResultsController.add(filtered);
        }
      });

      // Track scanning status
      _isScanningSubscription?.cancel();
      _isScanningSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
        _isScanning = isScanning;
        if (!isScanning && _currentStatus == 'Scanning') {
          _updateStatus(_connectedDevice != null ? 'Connected' : 'Disconnected');
        }
      });

      // Start scan without requiring location services check on Android (uses neverForLocation)
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: false,
        androidCheckLocationServices: false,
      );
    } catch (e) {
      _isScanning = false;
      _updateStatus('Connection Error', error: 'Scan failed: ${e.toString()}');
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      _isScanning = false;
      await FlutterBluePlus.stopScan();
      if (_currentStatus == 'Scanning') {
        _updateStatus(_connectedDevice != null ? 'Connected' : 'Disconnected');
      }
    } catch (_) {}
  }

  @override
  Future<bool> connectByAddress(String macAddress, {String? deviceName}) async {
    final clean = macAddress.trim().toUpperCase();
    if (clean.isEmpty) {
      _updateStatus('Connection Error', error: 'Bluetooth MAC address cannot be empty.');
      return false;
    }

    try {
      final device = BluetoothDevice.fromId(clean);
      return await connect(device);
    } catch (e) {
      _updateStatus('Connection Error', error: 'Failed to initialize device ($clean): ${e.toString()}');
      return false;
    }
  }

  @override
  Future<bool> connect(BluetoothDevice device) async {
    try {
      // 1. Stop any active scan to prevent Android GATT error 133
      await stopScan();

      _connectingDeviceId = device.remoteId.str;
      _updateStatus('Connecting');

      // 2. Disconnect existing device or subscriptions cleanly
      await _cleanConnection();
      _connectedDevice = device;

      // 3. Listen to connection state changes
      _deviceStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          _updateStatus('Connected');
          _connectingDeviceId = null;
        } else if (state == BluetoothConnectionState.disconnected) {
          _updateStatus('Disconnected');
          _connectedDevice = null;
          _connectingDeviceId = null;
          if (!_readingController.isClosed) {
            _readingController.add(SensorReading.disconnected(source: 'Bluetooth'));
          }
        }
      });

      // 4. Connect to device with timeout
      await device.connect(
        license: License.nonprofit,
        autoConnect: false,
        timeout: const Duration(seconds: 15),
      );

      // 5. Request MTU to allow larger sensor telemetry packets without fragmentation
      if (Platform.isAndroid) {
        try {
          await device.requestMtu(256);
        } catch (_) {}
      }

      _updateStatus('Connected');
      _connectingDeviceId = null;

      // 6. Discover services & subscribe to telemetry characteristics
      await _setupCharacteristicListener(device);
      return true;
    } catch (e) {
      _updateStatus('Connection Error', error: 'Bluetooth connection failed: ${e.toString()}');
      try {
        await device.disconnect();
      } catch (_) {}
      _connectedDevice = null;
      _connectingDeviceId = null;
      return false;
    }
  }

  Future<void> _cleanConnection() async {
    _rxBuffer.clear();
    _lastRxTime = null;
    await _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
    for (final sub in _characteristicSubscriptions) {
      await sub.cancel();
    }
    _characteristicSubscriptions.clear();
  }

  Future<void> _setupCharacteristicListener(BluetoothDevice device) async {
    try {
      // Brief delay to allow GATT database to stabilize on Android
      await Future.delayed(const Duration(milliseconds: 300));
      List<BluetoothService> services = await device.discoverServices();
      if (services.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        services = await device.discoverServices();
      }
      if (services.isEmpty) return;

      int notifyCharsFound = 0;

      // 1. If explicit target UUIDs are configured, prioritize them
      if (targetServiceUuid != null && targetCharacteristicUuid != null) {
        for (final service in services) {
          if (service.uuid.toString().toLowerCase() == targetServiceUuid!.toLowerCase()) {
            for (final char in service.characteristics) {
              if (char.uuid.toString().toLowerCase() == targetCharacteristicUuid!.toLowerCase()) {
                await _subscribeToCharacteristic(device, char);
                return;
              }
            }
          }
        }
      }

      // 2. Discover dynamically: subscribe to ALL characteristics that support notify or indicate
      // across non-generic services (supports Nordic UART, ESP32 BLE, LoRa nodes, Environmental Sensing, etc.)
      for (final service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();
        // Skip generic GAP/GATT services
        if (serviceUuid.contains('1800') || serviceUuid.contains('1801')) continue;

        for (final char in service.characteristics) {
          if (char.properties.notify || char.properties.indicate) {
            await _subscribeToCharacteristic(device, char);
            notifyCharsFound++;
          }
        }
      }

      // 3. Fallback: if no notify characteristics found, check readable characteristics
      if (notifyCharsFound == 0) {
        for (final service in services) {
          final serviceUuid = service.uuid.toString().toLowerCase();
          if (serviceUuid.contains('1800') || serviceUuid.contains('1801')) continue;

          for (final char in service.characteristics) {
            if (char.properties.read) {
              try {
                final bytes = await char.read();
                if (bytes.isNotEmpty) {
                  _processIncomingBytes(bytes);
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      _updateStatus('Connection Error', error: 'Service discovery error: ${e.toString()}');
    }
  }

  Future<void> _subscribeToCharacteristic(
    BluetoothDevice device,
    BluetoothCharacteristic char,
  ) async {
    try {
      await char.setNotifyValue(true);
      final sub = char.onValueReceived.listen((bytes) {
        if (bytes.isNotEmpty) {
          _processIncomingBytes(bytes);
        }
      });
      _characteristicSubscriptions.add(sub);
      device.cancelWhenDisconnected(sub);
    } catch (_) {}
  }

  // =========================================================================
  // HARDWARE DATA STREAM HANDLER & PARSER
  // =========================================================================
  void _processIncomingBytes(List<int> bytes) {
    if (bytes.isEmpty) return;

    final now = DateTime.now();
    // Clear buffer if packet stream timed out (> 3 seconds)
    if (_lastRxTime != null && now.difference(_lastRxTime!).inSeconds > 3) {
      _rxBuffer.clear();
    }
    _lastRxTime = now;

    // Check for direct parsing (e.g. complete payload or binary)
    final directReading = parseSensorPayload(bytes);
    if (directReading != null) {
      _rxBuffer.clear();
      if (!_readingController.isClosed) {
        _readingController.add(directReading);
      }
      return;
    }

    // Accumulate stream chunks in text buffer for fragmented transmissions
    try {
      final chunk = utf8.decode(bytes, allowMalformed: true);
      _rxBuffer.write(chunk);
      final accumulated = _rxBuffer.toString();

      // Check for newline / carriage return delimiters
      if (accumulated.contains('\n') || accumulated.contains('\r')) {
        final lines = accumulated.split(RegExp(r'[\r\n]+'));
        final endsWithNewline = accumulated.endsWith('\n') || accumulated.endsWith('\r');

        // Retain any trailing unfinished fragment in buffer
        if (!endsWithNewline) {
          _rxBuffer.clear();
          _rxBuffer.write(lines.last);
        } else {
          _rxBuffer.clear();
        }

        final count = endsWithNewline ? lines.length : lines.length - 1;
        for (int i = 0; i < count; i++) {
          final line = lines[i].trim();
          if (line.isNotEmpty) {
            final reading = parseSensorString(line);
            if (reading != null && !_readingController.isClosed) {
              _readingController.add(reading);
            }
          }
        }
      } else {
        // Try parsing accumulated buffer directly (for modules that don't send newlines)
        final reading = parseSensorString(accumulated.trim());
        if (reading != null) {
          _rxBuffer.clear();
          if (!_readingController.isClosed) {
            _readingController.add(reading);
          }
        } else if (accumulated.length > 512) {
          // Flush buffer if excessive junk data
          _rxBuffer.clear();
        }
      }
    } catch (_) {}
  }

  /// Parses raw byte payload (supporting JSON, delimited text, labeled text, and binary floats)
  SensorReading? parseSensorPayload(List<int> rawBytes) {
    if (rawBytes.isEmpty) return null;

    try {
      // 1. Text decoding
      final text = utf8.decode(rawBytes, allowMalformed: true).trim();
      if (text.isNotEmpty) {
        final reading = parseSensorString(text);
        if (reading != null) return reading;
      }

      // 2. Binary float format: 2 x 32-bit float (8 bytes)
      if (rawBytes.length >= 8) {
        final byteData = ByteData.sublistView(Uint8List.fromList(rawBytes));
        final temp = byteData.getFloat32(0, Endian.little);
        final hum = byteData.getFloat32(4, Endian.little);
        if (temp > -50 && temp < 150 && hum >= 0 && hum <= 100) {
          return SensorReading(
            temperature: temp,
            humidity: hum,
            timestamp: DateTime.now(),
            source: 'Bluetooth',
            connectionStatus: 'Connected',
          );
        }
      }
    } catch (_) {}

    return null;
  }

  /// Parses text strings in multiple IoT / LoRa telemetry formats
  SensorReading? parseSensorString(String text) {
    if (text.isEmpty) return null;

    try {
      // 1. JSON format: {"temperature": 28.5, "humidity": 65.0} or {"temp": 28.5, "hum": 65}
      if (text.contains('{') && text.contains('}')) {
        final start = text.indexOf('{');
        final end = text.lastIndexOf('}');
        if (end > start) {
          try {
            final jsonStr = text.substring(start, end + 1);
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            final tempVal = map['temperature'] ??
                map['temp'] ??
                map['t'] ??
                map['Temperature'] ??
                map['TEMP'] ??
                map['temperature_c'];
            final humVal = map['humidity'] ??
                map['hum'] ??
                map['h'] ??
                map['Humidity'] ??
                map['HUM'] ??
                map['humidity_pct'];
            final double? temp = (tempVal as num?)?.toDouble();
            final double? hum = (humVal as num?)?.toDouble();
            if (temp != null || hum != null) {
              return SensorReading(
                temperature: temp,
                humidity: hum,
                timestamp: DateTime.now(),
                source: 'Bluetooth',
                connectionStatus: 'Connected',
              );
            }
          } catch (_) {}
        }
      }

      // 2. Labeled key-value text in any order:
      // e.g. "Temp: 28.5 C, Humidity: 65.0%" or "T=28.5;H=65.0" or "Humidity: 65.0, Temp: 28.5"
      final tempMatch = RegExp(
        r'(?:temperature|temp|t)\s*[:=]?\s*([-+]?\d*\.?\d+)',
        caseSensitive: false,
      ).firstMatch(text);
      final humMatch = RegExp(
        r'(?:humidity|hum|h)\s*[:=]?\s*([-+]?\d*\.?\d+)',
        caseSensitive: false,
      ).firstMatch(text);

      if (tempMatch != null || humMatch != null) {
        final double? temp = tempMatch != null ? double.tryParse(tempMatch.group(1)!) : null;
        final double? hum = humMatch != null ? double.tryParse(humMatch.group(1)!) : null;
        if (temp != null || hum != null) {
          return SensorReading(
            temperature: temp,
            humidity: hum,
            timestamp: DateTime.now(),
            source: 'Bluetooth',
            connectionStatus: 'Connected',
          );
        }
      }

      // 3. Delimited numbers: e.g. "28.5, 65.0" or "28.5;65.0" or "28.5 65.0"
      final numbers = RegExp(r'[-+]?\d*\.?\d+')
          .allMatches(text)
          .map((m) => double.tryParse(m.group(0)!))
          .whereType<double>()
          .toList();

      if (numbers.length >= 2) {
        return SensorReading(
          temperature: numbers[0],
          humidity: numbers[1],
          timestamp: DateTime.now(),
          source: 'Bluetooth',
          connectionStatus: 'Connected',
        );
      } else if (numbers.length == 1) {
        return SensorReading(
          temperature: numbers[0],
          humidity: null,
          timestamp: DateTime.now(),
          source: 'Bluetooth',
          connectionStatus: 'Connected',
        );
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> disconnect() async {
    try {
      await _cleanConnection();
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
      }
      _connectingDeviceId = null;
      _updateStatus('Disconnected');
      if (!_readingController.isClosed) {
        _readingController.add(SensorReading.disconnected(source: 'Bluetooth'));
      }
    } catch (e) {
      _updateStatus('Connection Error', error: 'Disconnect error: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    stopScan();
    disconnect();
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _deviceStateSubscription?.cancel();
    for (final sub in _characteristicSubscriptions) {
      sub.cancel();
    }
    _characteristicSubscriptions.clear();
    _statusController.close();
    _scanResultsController.close();
    _bondedDevicesController.close();
    _readingController.close();
  }
}
