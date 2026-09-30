import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/sensor_reading.dart';

abstract class IStorageService {
  Future<List<UserModel>> loadUsers();
  Future<bool> saveUser(UserModel user);
  Future<UserModel?> findUserByEmail(String email);
  Future<bool> saveSensorReading(SensorReading reading, {String? userEmail});
  Future<SensorReading?> loadLatestReading({String? userEmail});
  Future<Map<String, SensorReading>> loadAllUserReadings();
  Future<void> saveSessionUser(UserModel? user);
  Future<UserModel?> loadSessionUser();
  Future<void> clearData();
}

class StorageService implements IStorageService {
  static const String _usersKey = 'app_registered_users';
  static const String _latestReadingKey = 'app_latest_sensor_reading';
  static const String _userReadingsKey = 'app_user_sensor_readings';
  static const String _sessionUserKey = 'app_session_user';

  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<List<UserModel>> loadUsers() async {
    await _init();
    final jsonString = _prefs?.getString(_usersKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> saveUser(UserModel user) async {
    await _init();
    final users = await loadUsers();
    final index = users.indexWhere((u) => u.email.toLowerCase() == user.email.toLowerCase());
    if (index >= 0) {
      users[index] = user;
    } else {
      users.add(user);
    }
    final jsonString = jsonEncode(users.map((u) => u.toJson()).toList());
    return await _prefs?.setString(_usersKey, jsonString) ?? false;
  }

  @override
  Future<UserModel?> findUserByEmail(String email) async {
    final users = await loadUsers();
    try {
      return users.firstWhere(
        (u) => u.email.toLowerCase().trim() == email.toLowerCase().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> saveSensorReading(SensorReading reading, {String? userEmail}) async {
    await _init();
    // Save global latest reading
    final readingJson = jsonEncode(reading.toJson());
    await _prefs?.setString(_latestReadingKey, readingJson);

    // Save per-user reading if userEmail is provided
    final email = userEmail ?? reading.userEmail;
    if (email != null && email.isNotEmpty) {
      final allReadings = await loadAllUserReadings();
      allReadings[email.toLowerCase()] = reading;
      final mapToSave = allReadings.map(
        (k, v) => MapEntry(k, v.toJson()),
      );
      await _prefs?.setString(_userReadingsKey, jsonEncode(mapToSave));
    }

    return true;
  }

  @override
  Future<SensorReading?> loadLatestReading({String? userEmail}) async {
    await _init();
    if (userEmail != null && userEmail.isNotEmpty) {
      final allReadings = await loadAllUserReadings();
      if (allReadings.containsKey(userEmail.toLowerCase())) {
        return allReadings[userEmail.toLowerCase()];
      }
    }
    final jsonString = _prefs?.getString(_latestReadingKey);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return SensorReading.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, SensorReading>> loadAllUserReadings() async {
    await _init();
    final jsonString = _prefs?.getString(_userReadingsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return {};
    }
    try {
      final Map<String, dynamic> rawMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final Map<String, SensorReading> result = {};
      rawMap.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          result[key] = SensorReading.fromJson(value);
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveSessionUser(UserModel? user) async {
    await _init();
    if (user == null) {
      await _prefs?.remove(_sessionUserKey);
    } else {
      await _prefs?.setString(_sessionUserKey, jsonEncode(user.toJson()));
    }
  }

  @override
  Future<UserModel?> loadSessionUser() async {
    await _init();
    final jsonString = _prefs?.getString(_sessionUserKey);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    try {
      return UserModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearData() async {
    await _init();
    await _prefs?.remove(_usersKey);
    await _prefs?.remove(_latestReadingKey);
    await _prefs?.remove(_userReadingsKey);
    await _prefs?.remove(_sessionUserKey);
  }
}
