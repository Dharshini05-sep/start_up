import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:start_up/models/user_model.dart';
import 'package:start_up/models/sensor_reading.dart';
import 'package:start_up/services/storage_service.dart';
import 'package:start_up/services/auth_service.dart';
import 'package:start_up/services/bluetooth_service.dart';

class MockStorageService implements IStorageService {
  final Map<String, UserModel> users = {};
  SensorReading? latestReading;
  final Map<String, SensorReading> userReadings = {};
  UserModel? sessionUser;

  @override
  Future<void> clearData() async {
    users.clear();
    latestReading = null;
    userReadings.clear();
    sessionUser = null;
  }

  @override
  Future<UserModel?> findUserByEmail(String email) async => users[email.toLowerCase()];

  @override
  Future<Map<String, SensorReading>> loadAllUserReadings() async => userReadings;

  @override
  Future<SensorReading?> loadLatestReading({String? userEmail}) async {
    if (userEmail != null) return userReadings[userEmail.toLowerCase()];
    return latestReading;
  }

  @override
  Future<UserModel?> loadSessionUser() async => sessionUser;

  @override
  Future<List<UserModel>> loadUsers() async => users.values.toList();

  @override
  Future<bool> saveSensorReading(SensorReading reading, {String? userEmail}) async {
    latestReading = reading;
    if (userEmail != null) {
      userReadings[userEmail.toLowerCase()] = reading;
    }
    return true;
  }

  @override
  Future<void> saveSessionUser(UserModel? user) async {
    sessionUser = user;
  }

  @override
  Future<bool> saveUser(UserModel user) async {
    users[user.email.toLowerCase()] = user;
    return true;
  }
}

void main() {
  group('Authentication and Models Test', () {
    late MockStorageService storage;
    late AuthService authService;

    setUp(() {
      storage = MockStorageService();
      authService = AuthService(storage);
    });

    test('Admin login with default credentials succeeds', () async {
      final result = await authService.login(
        email: 'admin@example.com',
        password: '123456789',
        accountType: 'Doctor',
      );
      expect(result.success, isTrue);
      expect(result.isAdmin, isTrue);
      expect(authService.isAdmin, isTrue);
    });

    test('Doctor signup and login succeeds with matching password hash', () async {
      final signupResult = await authService.signUp(
        firstName: 'John',
        lastName: 'Doe',
        email: 'john.doe@hospital.com',
        password: 'password123',
        confirmPassword: 'password123',
        accountType: 'Doctor',
      );
      expect(signupResult.success, isTrue);
      expect(signupResult.user?.fullName, equals('John Doe'));

      final loginResult = await authService.login(
        email: 'john.doe@hospital.com',
        password: 'password123',
        accountType: 'Doctor',
      );
      expect(loginResult.success, isTrue);
      expect(loginResult.isAdmin, isFalse);
    });

    test('Guardian signup and login succeeds with isGuardian flag', () async {
      final signupResult = await authService.signUp(
        firstName: 'Jane',
        lastName: 'Guardian',
        email: 'jane.guardian@example.com',
        password: 'password123',
        confirmPassword: 'password123',
        accountType: 'Guardian',
      );
      expect(signupResult.success, isTrue);
      expect(signupResult.user?.accountType, equals('Guardian'));

      final loginResult = await authService.login(
        email: 'jane.guardian@example.com',
        password: 'password123',
        accountType: 'Guardian',
      );
      expect(loginResult.success, isTrue);
      expect(authService.isGuardian, isTrue);
      expect(authService.isAdmin, isFalse);
    });

    test('SensorReading formats placeholders when disconnected', () {
      final reading = SensorReading.disconnected(source: 'Bluetooth');
      expect(reading.temperatureDisplay, equals('-- °C'));
      expect(reading.humidityDisplay, equals('-- %'));
      expect(reading.connectionStatus, equals('Disconnected'));
    });
  });

  group('LoRa Bluetooth Tests', () {
    test('Target LoRa constants are configured correctly', () {
      expect(BluetoothSensorService.defaultTargetMacAddress, equals('58:BF:25:EE:FF:F2'));
      expect(BluetoothSensorService.defaultTargetDeviceName, equals('ESP32-BT-Master'));
    });

    test('parseSensorPayload parses JSON format', () {
      final service = BluetoothSensorService();
      final bytes = utf8.encode('{"temperature": 27.5, "humidity": 65.0}');
      final reading = service.parseSensorPayload(bytes);
      expect(reading, isNotNull);
      expect(reading!.temperature, equals(27.5));
      expect(reading.humidity, equals(65.0));
      expect(reading.source, equals('Bluetooth'));
      expect(reading.connectionStatus, equals('Connected'));
    });

    test('parseSensorPayload parses delimited text format', () {
      final service = BluetoothSensorService();
      final bytes = utf8.encode('28.3, 72.1');
      final reading = service.parseSensorPayload(bytes);
      expect(reading, isNotNull);
      expect(reading!.temperature, equals(28.3));
      expect(reading.humidity, equals(72.1));
    });

    test('parseSensorPayload parses labeled text format', () {
      final service = BluetoothSensorService();
      final bytes = utf8.encode('Temp: 31.4 C, Humidity: 45.2%');
      final reading = service.parseSensorPayload(bytes);
      expect(reading, isNotNull);
      expect(reading!.temperature, equals(31.4));
      expect(reading.humidity, equals(45.2));
    });

    test('parseSensorPayload parses reverse labeled text format', () {
      final service = BluetoothSensorService();
      final bytes = utf8.encode('Humidity: 55.0 %, Temp: 24.8 C');
      final reading = service.parseSensorPayload(bytes);
      expect(reading, isNotNull);
      expect(reading!.temperature, equals(24.8));
      expect(reading.humidity, equals(55.0));
    });

    test('parseSensorPayload parses key-value formats', () {
      final service = BluetoothSensorService();
      final bytes = utf8.encode('T=29.2;H=58.4');
      final reading = service.parseSensorPayload(bytes);
      expect(reading, isNotNull);
      expect(reading!.temperature, equals(29.2));
      expect(reading.humidity, equals(58.4));
    });

    test('parseSensorPayload parses short keys JSON', () {
      final service = BluetoothSensorService();
      final bytes = utf8.encode('{"t": 22.0, "h": 70.0}');
      final reading = service.parseSensorPayload(bytes);
      expect(reading, isNotNull);
      expect(reading!.temperature, equals(22.0));
      expect(reading.humidity, equals(70.0));
    });
  });
}
