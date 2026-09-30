import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/user_model.dart';
import '../models/sensor_reading.dart';

class AdminReportRow {
  final UserModel user;
  final SensorReading? reading;

  const AdminReportRow({
    required this.user,
    this.reading,
  });
}

class PdfService {
  /// Generates the PDF document as bytes
  static Future<Uint8List> generateAdminReport({
    required List<AdminReportRow> rows,
    required SensorReading? latestGlobalReading,
  }) async {
    final pdf = pw.Document();
    final nowFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Sensor Monitoring System - Admin Report',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.Text(
                  'Generated: $nowFormatted',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Confidential Medical & Environmental Telemetry Audit',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'LoRa Telemetry Healthcare Platform',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          // Metrics summary bar
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCell('Total Registered Users', rows.length.toString()),
                _buildMetricCell(
                  'Doctors',
                  rows.where((r) => r.user.accountType.toLowerCase() == 'doctor').length.toString(),
                ),
                _buildMetricCell(
                  'Guardians',
                  rows.where((r) => r.user.accountType.toLowerCase() == 'guardian').length.toString(),
                ),
                _buildMetricCell(
                  'Active Sensor Link',
                  latestGlobalReading?.connectionStatus == 'Connected' ? 'Active' : 'Offline',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Main data table
          if (rows.isEmpty)
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(32),
                child: pw.Text(
                  'No registered accounts found in the database.',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'First Name',
                'Last Name',
                'Email',
                'Type',
                'Temperature',
                'Humidity',
                'Timestamp',
                'Source',
                'Status',
              ],
              data: rows.map((row) {
                final reading = row.reading;
                return [
                  row.user.firstName,
                  row.user.lastName,
                  row.user.email,
                  row.user.accountType,
                  reading?.temperature != null
                      ? '${reading!.temperature!.toStringAsFixed(1)} °C'
                      : 'Not Available',
                  reading?.humidity != null
                      ? '${reading!.humidity!.toStringAsFixed(1)} %'
                      : 'Not Available',
                  reading?.timestamp != null
                      ? DateFormat('yyyy-MM-dd HH:mm:ss').format(reading!.timestamp!)
                      : 'Not Available',
                  reading?.source ?? 'Not Available',
                  reading?.connectionStatus ?? 'Disconnected',
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
            ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetricCell(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  /// Generates the PDF and presents the native Android share / save sheet
  static Future<void> shareOrSaveReport({
    required List<AdminReportRow> rows,
    required SensorReading? latestGlobalReading,
  }) async {
    final pdfBytes = await generateAdminReport(
      rows: rows,
      latestGlobalReading: latestGlobalReading,
    );

    final dateStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Sensor_Admin_Report_$dateStamp.pdf',
    );
  }
}
