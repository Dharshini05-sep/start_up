import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/mysql_storage_service.dart';
import 'services/auth_service.dart';
import 'services/bluetooth_service.dart';
import 'services/ip_sensor_service.dart';
import 'pages/signup_page.dart';
import 'pages/login_page.dart';
import 'pages/doctor_page.dart';
import 'pages/guardian_page.dart';
import 'pages/admin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localStorage = await StorageService.getInstance();
  final storageService = MysqlStorageService(localStorage: localStorage);
  final authService = AuthService(storageService);
  await authService.initSession();

  final bluetoothService = BluetoothSensorService();
  final ipSensorService = IpSensorService();

  runApp(LoRaMonitorApp(
    authService: authService,
    storageService: storageService,
    bluetoothService: bluetoothService,
    ipSensorService: ipSensorService,
  ));
}

class LoRaMonitorApp extends StatefulWidget {
  final AuthService authService;
  final IStorageService storageService;
  final IBluetoothService bluetoothService;
  final IIpSensorService ipSensorService;

  const LoRaMonitorApp({
    super.key,
    required this.authService,
    required this.storageService,
    required this.bluetoothService,
    required this.ipSensorService,
  });

  @override
  State<LoRaMonitorApp> createState() => _LoRaMonitorAppState();
}

class _LoRaMonitorAppState extends State<LoRaMonitorApp> {
  @override
  void dispose() {
    widget.bluetoothService.dispose();
    widget.ipSensorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine initial route based on existing session state
    String initialRoute = '/login';
    if (widget.authService.isAuthenticated) {
      if (widget.authService.isAdmin) {
        initialRoute = '/admin';
      } else if (widget.authService.isGuardian) {
        initialRoute = '/guardian';
      } else {
        initialRoute = '/doctor';
      }
    }

    return MaterialApp(
      title: 'LoRa Telemetry Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E), // Deep Teal
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2),
          ),
        ),
      ),
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/signup':
            return MaterialPageRoute(
              builder: (_) => SignUpPage(authService: widget.authService),
            );

          case '/login':
            return MaterialPageRoute(
              builder: (_) => LoginPage(authService: widget.authService),
            );

          case '/doctor':
            // Route guard: only authenticated Doctor users can access
            if (!widget.authService.isAuthenticated) {
              return MaterialPageRoute(
                builder: (_) => LoginPage(authService: widget.authService),
              );
            }
            return MaterialPageRoute(
              builder: (_) => DoctorPage(
                authService: widget.authService,
                storageService: widget.storageService,
                bluetoothService: widget.bluetoothService,
                ipSensorService: widget.ipSensorService,
              ),
            );

          case '/guardian':
            // Route guard: only authenticated Guardian users can access
            if (!widget.authService.isAuthenticated) {
              return MaterialPageRoute(
                builder: (_) => LoginPage(authService: widget.authService),
              );
            }
            return MaterialPageRoute(
              builder: (_) => GuardianPage(
                authService: widget.authService,
                storageService: widget.storageService,
              ),
            );

          case '/admin':
            // Route guard: only administrator can access Admin Dashboard
            if (!widget.authService.isAuthenticated || !widget.authService.isAdmin) {
              return MaterialPageRoute(
                builder: (_) => LoginPage(authService: widget.authService),
              );
            }
            return MaterialPageRoute(
              builder: (_) => AdminPage(
                authService: widget.authService,
                storageService: widget.storageService,
              ),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => LoginPage(authService: widget.authService),
            );
        }
      },
    );
  }
}