import 'package:flutter/material.dart';
import '../models/sensor_reading.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/pdf_service.dart';
import '../widgets/monitoring_table.dart';

class AdminPage extends StatefulWidget {
  final AuthService authService;
  final IStorageService storageService;

  const AdminPage({
    super.key,
    required this.authService,
    required this.storageService,
  });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<AdminReportRow> _rows = [];
  SensorReading? _globalLatestReading;
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final users = await widget.storageService.loadUsers();
      final userReadings = await widget.storageService.loadAllUserReadings();
      _globalLatestReading = await widget.storageService.loadLatestReading();

      final List<AdminReportRow> rows = [];
      for (final user in users) {
        // Find reading specific to this user, or fallback to global if connected by this user
        SensorReading? reading = userReadings[user.email.toLowerCase()];
        if (reading == null && _globalLatestReading?.userEmail == user.email) {
          reading = _globalLatestReading;
        }
        rows.add(AdminReportRow(user: user, reading: reading));
      }

      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard data: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _handleDownloadPdf() async {
    setState(() => _isExporting = true);
    try {
      await PdfService.shareOrSaveReport(
        rows: _rows,
        latestGlobalReading: _globalLatestReading,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.white),
                SizedBox(width: 12),
                Text('PDF report generated successfully.'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generation failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the Admin Dashboard?'),
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
    final totalUsers = _rows.length;
    final totalDoctors = _rows.where((r) => r.user.accountType.toLowerCase() == 'doctor').length;
    final totalGuardians = _rows.where((r) => r.user.accountType.toLowerCase() == 'guardian').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _isLoading ? null : _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Metric Cards Row
                      Row(
                        children: [
                          _buildMetricCard(
                            theme: theme,
                            label: 'Total Users',
                            value: totalUsers.toString(),
                            icon: Icons.people_alt_outlined,
                            color: Colors.indigo,
                          ),
                          const SizedBox(width: 12),
                          _buildMetricCard(
                            theme: theme,
                            label: 'Doctors',
                            value: totalDoctors.toString(),
                            icon: Icons.medical_services_outlined,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 12),
                          _buildMetricCard(
                            theme: theme,
                            label: 'Guardians',
                            value: totalGuardians.toString(),
                            icon: Icons.family_restroom_outlined,
                            color: Colors.deepPurple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section Title and "Download PDF" button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Registered Accounts & Telemetry',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: (_isExporting || _rows.isEmpty)
                                ? null
                                : _handleDownloadPdf,
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: const Text('Download PDF'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blueGrey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Excel-like table with horizontal scrolling
                      MonitoringTable(rows: _rows),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMetricCard({
    required ThemeData theme,
    required String label,
    required String value,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color.shade700, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color.shade900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
