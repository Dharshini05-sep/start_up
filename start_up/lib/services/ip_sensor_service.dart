import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/sensor_reading.dart';

enum NetworkProtocol {
  rawTcp,
  httpPolling,
}

abstract class IIpSensorService {
  Stream<String> get statusStream;
  Stream<SensorReading> get readingStream;
  String get currentStatus;
  String? get lastError;
  bool get isConnected;

  Future<bool> connect({required String ip, required int port});
  Future<void> disconnect();
  void dispose();
}

class IpSensorService implements IIpSensorService {
  // =========================================================================
  // HARDWARE NETWORK CONFIGURATION PLACEHOLDER
  // =========================================================================
  // Specify whether the LoRa gateway / device uses raw TCP stream or HTTP REST endpoints.
  // When hardware specifications are provided, configure protocol and payload endpoints here.
  static const NetworkProtocol configuredProtocol = NetworkProtocol.rawTcp;

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  final StreamController<SensorReading> _readingController =
      StreamController<SensorReading>.broadcast();

  String _currentStatus = 'Disconnected';
  String? _lastError;
  Socket? _socket;
  StreamSubscription<List<int>>? _socketSubscription;

  @override
  Stream<String> get statusStream => _statusController.stream;

  @override
  Stream<SensorReading> get readingStream => _readingController.stream;

  @override
  String get currentStatus => _currentStatus;

  @override
  String? get lastError => _lastError;

  @override
  bool get isConnected => _currentStatus == 'Connected';

  void _updateStatus(String newStatus, {String? error}) {
    _currentStatus = newStatus;
    _lastError = error;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  /// Validates IPv4 or IPv6 format
  static bool isValidIp(String ip) {
    if (ip.trim().isEmpty) return false;
    final address = InternetAddress.tryParse(ip.trim());
    return address != null;
  }

  /// Validates network port number (1 - 65535)
  static bool isValidPort(String portStr) {
    final port = int.tryParse(portStr.trim());
    return port != null && port >= 1 && port <= 65535;
  }

  @override
  Future<bool> connect({required String ip, required int port}) async {
    final cleanIp = ip.trim();
    if (!isValidIp(cleanIp)) {
      _updateStatus(
        'Connection Error',
        error: 'Invalid IP address format (e.g. 192.168.1.100).',
      );
      return false;
    }

    if (port < 1 || port > 65535) {
      _updateStatus(
        'Connection Error',
        error: 'Port must be between 1 and 65535.',
      );
      return false;
    }

    await disconnect();
    _updateStatus('Connecting');

    try {
      if (configuredProtocol == NetworkProtocol.rawTcp) {
        final address = InternetAddress(cleanIp);
        _socket = await Socket.connect(
          address,
          port,
          timeout: const Duration(seconds: 5),
        );

        _updateStatus('Connected');

        _socketSubscription = _socket!.listen(
          (data) {
            final text = utf8.decode(data, allowMalformed: true);
            final reading = parseNetworkPacket(text);
            if (reading != null && !_readingController.isClosed) {
              _readingController.add(reading);
            }
          },
          onError: (error) {
            _updateStatus(
              'Connection Error',
              error: 'Socket error: ${error.toString()}',
            );
            disconnect();
          },
          onDone: () {
            _updateStatus('Disconnected');
            disconnect();
          },
          cancelOnError: true,
        );
        return true;
      } else {
        // HTTP REST architecture placeholder
        _updateStatus(
          'Connection Error',
          error: 'HTTP Protocol awaiting hardware API specification.',
        );
        return false;
      }
    } on SocketException catch (e) {
      _updateStatus(
        'Connection Error',
        error: 'Cannot reach sensor at $cleanIp:$port (${e.message}).',
      );
      return false;
    } on TimeoutException {
      _updateStatus(
        'Connection Error',
        error: 'Connection to $cleanIp:$port timed out.',
      );
      return false;
    } catch (e) {
      _updateStatus(
        'Connection Error',
        error: 'Network connection failed: ${e.toString()}',
      );
      return false;
    }
  }

  // =========================================================================
  // NETWORK DATA PARSER PLACEHOLDER
  // =========================================================================
  // Parses payload from TCP socket / HTTP response.
  // Does NOT generate fake data. Returns null if unknown packet.
  SensorReading? parseNetworkPacket(String rawData) {
    if (rawData.trim().isEmpty) return null;

    // Example future protocol implementation (JSON/CSV/MODBUS):
    // try {
    //   final json = jsonDecode(rawData);
    //   return SensorReading(...);
    // } catch (_) {}
    return null;
  }

  @override
  Future<void> disconnect() async {
    try {
      await _socketSubscription?.cancel();
      _socketSubscription = null;
      if (_socket != null) {
        await _socket!.close();
        _socket?.destroy();
        _socket = null;
      }
      _updateStatus('Disconnected');
      if (!_readingController.isClosed) {
        _readingController.add(SensorReading.disconnected(source: 'IP/Wi-Fi'));
      }
    } catch (e) {
      _updateStatus('Connection Error', error: 'Disconnect error: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    disconnect();
    _statusController.close();
    _readingController.close();
  }
}
