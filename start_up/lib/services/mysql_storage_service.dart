import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/sensor_reading.dart';
import 'storage_service.dart';

class MysqlStorageService implements IStorageService {
  // Target IP address of the host machine running XAMPP Apache
  // 10.235.251.139 is your PC's Wi-Fi LAN IP address reachable by your physical phone CPH2751
  static const String defaultBaseUrl = 'http://10.235.251.139/start_app/api';

  final String baseUrl;
  final IStorageService localStorage;
  final http.Client _httpClient;

  MysqlStorageService({
    String? baseUrl,
    required this.localStorage,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ?? defaultBaseUrl,
        _httpClient = httpClient ?? http.Client();

  @override
  Future<List<UserModel>> loadUsers() async {
    try {
      final uri = Uri.parse('$baseUrl/get_users.php');
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success' && data['users'] is List) {
          final List<dynamic> list = data['users'] as List<dynamic>;
          final users = list
              .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
              .toList();

          // Sync local cache
          for (final u in users) {
            await localStorage.saveUser(u);
          }
          return users;
        }
      }
    } catch (e) {
      // Fallback to local storage if server is unreachable
    }
    return localStorage.loadUsers();
  }

  @override
  Future<bool> saveUser(UserModel user) async {
    // Always persist to local cache first
    await localStorage.saveUser(user);

    try {
      final uri = Uri.parse('$baseUrl/signup.php');
      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(user.toJson()),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } catch (e) {
      // Offline fallback: user is stored locally and can be synced later
    }
    return true;
  }

  @override
  Future<UserModel?> findUserByEmail(String email) async {
    try {
      final uri = Uri.parse('$baseUrl/find_user.php?email=${Uri.encodeComponent(email)}');
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success' && data['user'] is Map<String, dynamic>) {
          final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
          await localStorage.saveUser(user);
          return user;
        }
      }
    } catch (e) {
      // Fallback to local cache
    }
    return localStorage.findUserByEmail(email);
  }

  @override
  Future<bool> saveSensorReading(SensorReading reading, {String? userEmail}) async {
    // Save to local cache
    await localStorage.saveSensorReading(reading, userEmail: userEmail);

    try {
      final uri = Uri.parse('$baseUrl/save_reading.php');
      final payload = reading.copyWith(userEmail: userEmail ?? reading.userEmail).toJson();

      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } catch (e) {
      // Offline fallback
    }
    return true;
  }

  @override
  Future<SensorReading?> loadLatestReading({String? userEmail}) async {
    try {
      final uri = Uri.parse('$baseUrl/get_readings.php');
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          if (userEmail != null && data['userReadings'] is Map) {
            final userMap = data['userReadings'] as Map<String, dynamic>;
            final key = userEmail.toLowerCase();
            if (userMap.containsKey(key)) {
              return SensorReading.fromJson(userMap[key] as Map<String, dynamic>);
            }
          }
          if (data['latestGlobal'] != null) {
            return SensorReading.fromJson(data['latestGlobal'] as Map<String, dynamic>);
          }
        }
      }
    } catch (e) {
      // Fallback to local cache
    }
    return localStorage.loadLatestReading(userEmail: userEmail);
  }

  @override
  Future<Map<String, SensorReading>> loadAllUserReadings() async {
    try {
      final uri = Uri.parse('$baseUrl/get_readings.php');
      final response = await _httpClient.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success' && data['userReadings'] is Map) {
          final rawMap = data['userReadings'] as Map<String, dynamic>;
          final Map<String, SensorReading> result = {};
          rawMap.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              result[key] = SensorReading.fromJson(value);
            }
          });
          return result;
        }
      }
    } catch (e) {
      // Fallback to local cache
    }
    return localStorage.loadAllUserReadings();
  }

  @override
  Future<void> saveSessionUser(UserModel? user) => localStorage.saveSessionUser(user);

  @override
  Future<UserModel?> loadSessionUser() => localStorage.loadSessionUser();

  @override
  Future<void> clearData() async {
    await localStorage.clearData();
  }
}
