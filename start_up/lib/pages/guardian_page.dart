import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor_reading.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/sensor_card.dart';

class GuardianPage extends StatefulWidget {
  final AuthService authService;
  final IStorageService storageService;

  const GuardianPage({
    super.key,
    required this.authService,
    required this.storageService,
  });

  @override
  State<GuardianPage> createState() => _GuardianPageState();
}

class _GuardianPageState extends State<GuardianPage> {
  SensorReading _currentReading = SensorReading.disconnected();
  bool _isLoading = false;
  Timer? _pollingTimer;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _fetchLatestReading();
    // Poll for the latest readings every 4 seconds from MySQL/storage
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchLatestReading(isBackground: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLatestReading({bool isBackground = false}) async {
    if (!isBackground && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final reading = await widget.storageService.loadLatestReading();
      if (mounted) {
        setState(() {
          if (reading != null) {
            _currentReading = reading;
            _lastSyncTime = DateTime.now();
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the Guardian portal?'),
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
      await widget.authService.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.authService.currentUser;
    final hasData = _currentReading.hasValidData;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guardian Monitoring',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (user != null)
              Text(
                '${user.fullName} (Guardian)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Vitals',
            onPressed: _isLoading ? null : () => _fetchLatestReading(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchLatestReading(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Informational Card
                  _buildPatientOverviewCard(theme),
                  const SizedBox(height: 20),

                  // Sensor Vitals Section
                  _buildVitalsCard(theme, hasData),
                  const SizedBox(height: 20),

                  // Live Sync Status Card
                  _buildLiveStatusCard(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientOverviewCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Patient Remote Telemetry',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Real-time vital readings synced securely from the clinic and sensor gateway.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsCard(ThemeData theme, bool hasData) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_heart_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Live Patient Vitals',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasData ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hasData ? Colors.green.shade300 : Colors.amber.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasData ? Colors.green : Colors.amber.shade700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasData ? 'Active Telemetry' : 'Waiting for Data',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasData ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Temperature and Humidity Cards
            Row(
              children: [
                SensorCard(
                  type: SensorType.temperature,
                  value: _currentReading.temperature,
                  isConnected: _currentReading.temperature != null,
                ),
                const SizedBox(width: 16),
                SensorCard(
                  type: SensorType.humidity,
                  value: _currentReading.humidity,
                  isConnected: _currentReading.humidity != null,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reading metadata
            if (_currentReading.timestamp != null) ...[
              Center(
                child: Text(
                  'Sensor Timestamp: ${_currentReading.formattedTimestamp}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatusCard(ThemeData theme) {
    final syncText = _lastSyncTime != null
        ? '${_lastSyncTime!.hour.toString().padLeft(2, '0')}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}:${_lastSyncTime!.second.toString().padLeft(2, '0')}'
        : 'Connecting...';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.sync, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Auto-syncing every 4s',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const Spacer(),
          Text(
            'Last sync: $syncText',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
