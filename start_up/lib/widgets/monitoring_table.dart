import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/pdf_service.dart';

class MonitoringTable extends StatelessWidget {
  final List<AdminReportRow> rows;

  const MonitoringTable({
    super.key,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No Registered Users',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Registered doctors and guardians will appear here once they create accounts.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              const Color(0xFF1E293B), // Professional dark navy/slate
            ),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            horizontalMargin: 16,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('First Name')),
              DataColumn(label: Text('Last Name')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Temperature')),
              DataColumn(label: Text('Humidity')),
              DataColumn(label: Text('Timestamp')),
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Status')),
            ],
            rows: rows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              final reading = row.reading;
              final isEven = index % 2 == 0;

              final String tempDisplay = reading?.temperature != null
                  ? '${reading!.temperature!.toStringAsFixed(1)} °C'
                  : 'Not Available';

              final String humDisplay = reading?.humidity != null
                  ? '${reading!.humidity!.toStringAsFixed(1)} %'
                  : 'Not Available';

              final String timeDisplay = reading?.timestamp != null
                  ? DateFormat('yyyy-MM-dd HH:mm:ss').format(reading!.timestamp!)
                  : 'Not Available';

              final String sourceDisplay = reading?.source ?? 'Not Available';
              final String statusDisplay = reading?.connectionStatus ?? 'Disconnected';

              return DataRow(
                color: WidgetStateProperty.all(
                  isEven ? Colors.white : Colors.grey.shade50,
                ),
                cells: [
                  DataCell(Text(row.user.firstName, style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(row.user.lastName, style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(row.user.email)),
                  DataCell(_buildTypeBadge(row.user.accountType)),
                  DataCell(Text(
                    tempDisplay,
                    style: TextStyle(
                      fontWeight: reading?.temperature != null ? FontWeight.bold : FontWeight.normal,
                      color: reading?.temperature != null ? Colors.orange.shade800 : Colors.grey.shade600,
                    ),
                  )),
                  DataCell(Text(
                    humDisplay,
                    style: TextStyle(
                      fontWeight: reading?.humidity != null ? FontWeight.bold : FontWeight.normal,
                      color: reading?.humidity != null ? Colors.blue.shade800 : Colors.grey.shade600,
                    ),
                  )),
                  DataCell(Text(
                    timeDisplay,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  )),
                  DataCell(Text(sourceDisplay)),
                  DataCell(_buildStatusBadge(statusDisplay)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String accountType) {
    final isDoctor = accountType.toLowerCase() == 'doctor';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDoctor ? Colors.teal.shade50 : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDoctor ? Colors.teal.shade200 : Colors.indigo.shade200,
        ),
      ),
      child: Text(
        accountType,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDoctor ? Colors.teal.shade800 : Colors.indigo.shade800,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'connected':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'scanning':
      case 'connecting':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        break;
      case 'connection error':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      case 'disconnected':
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
