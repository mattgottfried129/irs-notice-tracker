import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/notice.dart';
import '../models/poa_record.dart';
import '../models/client.dart';
import '../models/call.dart';
import '../services/client_service.dart';

class PrintDashboardScreen extends StatefulWidget {
  const PrintDashboardScreen({super.key});

  @override
  State<PrintDashboardScreen> createState() => _PrintDashboardScreenState();
}

class _PrintDashboardScreenState extends State<PrintDashboardScreen> {
  bool _isLoading = false;
  DateTime _reportDate = DateTime.now();

  Future<Map<String, dynamic>> _loadDashboardData() async {
    final firestore = FirebaseFirestore.instance;

    // Load all data
    final noticesSnapshot = await firestore.collection('notices').get();
    final poaSnapshot = await firestore.collection('poaRecords').get();
    final callsSnapshot = await firestore.collection('calls').get();
    final clients = await ClientService.getClients();

    final notices = noticesSnapshot.docs.map((doc) {
      return Notice.fromMap(doc.data(), doc.id);
    }).toList();

    final poaRecords = poaSnapshot.docs.map((doc) {
      return PoaRecord.fromMap(doc.data(), doc.id);
    }).toList();

    final calls = callsSnapshot.docs.map((doc) {
      return Call.fromMap(doc.data(), doc.id);
    }).toList();

    // Build client map
    final clientMap = {for (var c in clients) c.id: c};

    return {
      'notices': notices,
      'poaRecords': poaRecords,
      'calls': calls,
      'clientMap': clientMap,
    };
  }

  bool _hasValidPOA(Notice notice, List<PoaRecord> poaRecords) {
    if (notice.formNumber == null || notice.taxPeriod == null) return false;

    final noticePeriodInt = int.tryParse(notice.taxPeriod!);
    if (noticePeriodInt == null) return false;

    return poaRecords.any((p) {
      final start = int.tryParse(p.periodStart);
      final end = int.tryParse(p.periodEnd);
      if (start == null || end == null) return false;

      return p.clientId == notice.clientId &&
          p.form == notice.formNumber &&
          noticePeriodInt >= start &&
          noticePeriodInt <= end;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Print Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: "Select Report Date",
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _reportDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  _reportDate = picked;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadDashboardData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading data: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final notices = data['notices'] as List<Notice>;
          final poaRecords = data['poaRecords'] as List<PoaRecord>;
          final calls = data['calls'] as List<Call>;
          final clientMap = data['clientMap'] as Map<String, Client>;

          return PdfPreview(
            build: (format) => _generatePdf(
              format,
              notices,
              poaRecords,
              calls,
              clientMap,
            ),
          );
        },
      ),
    );
  }

  Future<Uint8List> _generatePdf(
      PdfPageFormat format,
      List<Notice> notices,
      List<PoaRecord> poaRecords,
      List<Call> calls,
      Map<String, Client> clientMap,
      ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MM/dd/yyyy');

    // Calculate statistics
    final openNotices = notices.where((n) => n.status == "Open").toList();
    final inProgressNotices = notices.where((n) => n.status == "In Progress").toList();
    final waitingNotices = notices.where((n) =>
    n.status == "Waiting on Client" || n.status == "Awaiting IRS Response"
    ).toList();
    final escalatedNotices = notices.where((n) => n.status == "Escalated").toList();
    final closedNotices = notices.where((n) => n.status == "Closed").toList();
    final missingPoaNotices = notices.where((n) => !_hasValidPOA(n, poaRecords)).toList();

    // Sort notices by due date
    final dueNotices = notices
        .where((n) => n.status != "Closed")
        .toList()
      ..sort((a, b) {
        final aDue = a.dueDate ?? DateTime.now().add(const Duration(days: 365));
        final bDue = b.dueDate ?? DateTime.now().add(const Duration(days: 365));
        return aDue.compareTo(bDue);
      });

    final upcomingDue = dueNotices.take(15).toList();

    // Calculate billing stats
    final unbilledCalls = calls.where((c) => c.billing == "Unbilled" && c.billable).toList();
    final unbilledTotal = unbilledCalls.fold<double>(
      0.0,
          (sum, call) => sum + call.calculateBillableAmount(calls),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "TAX & BUSINESS SOLUTIONS",
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "CERTIFIED PUBLIC ACCOUNTANT & Co., LLC",
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "IRS NOTICE TRACKER - QUICK DASHBOARD",
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "Report Date:",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(dateFormat.format(_reportDate)),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    "Generated:",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(DateFormat('MM/dd/yyyy hh:mm a').format(DateTime.now())),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 24),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 16),

          // Summary Statistics
          pw.Text(
            "NOTICE SUMMARY",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 12),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              _buildTableRow("Open Notices", openNotices.length.toString(), isHeader: true),
              _buildTableRow("In Progress", inProgressNotices.length.toString()),
              _buildTableRow("Waiting (Client/IRS)", waitingNotices.length.toString()),
              _buildTableRow("Escalated", escalatedNotices.length.toString(), isEscalated: true),
              _buildTableRow("Closed (This Period)", closedNotices.length.toString()),
              _buildTableRow("Missing POA", missingPoaNotices.length.toString(), isMissing: true),
              _buildTableRow("TOTAL ACTIVE", (notices.length - closedNotices.length).toString(), isTotal: true),
            ],
          ),

          pw.SizedBox(height: 24),

          // Billing Summary
          pw.Text(
            "BILLING SUMMARY",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 12),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              _buildTableRow("Unbilled Calls", unbilledCalls.length.toString(), isHeader: true),
              _buildTableRow("Unbilled Amount", "\$${unbilledTotal.toStringAsFixed(2)}", isMoney: true),
            ],
          ),

          pw.SizedBox(height: 24),

          // Upcoming Due Notices
          pw.Text(
            "UPCOMING DUE NOTICES (Next 15)",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.SizedBox(height: 12),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text("Notice ID", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text("Client", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text("Status", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text("Due Date", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text("Days", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text("POA", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              // Data rows
              ...upcomingDue.map((notice) {
                final client = clientMap[notice.clientId];
                final dueDate = notice.dueDate;
                final daysRemaining = dueDate != null
                    ? dueDate.difference(DateTime.now()).inDays
                    : null;
                final hasPoa = _hasValidPOA(notice, poaRecords);

                return pw.TableRow(
                  decoration: !hasPoa ? const pw.BoxDecoration(color: PdfColors.orange50) : null,
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(notice.autoId ?? notice.noticeNumber, style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(client?.name ?? notice.clientId, style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(notice.status, style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(dueDate != null ? dateFormat.format(dueDate) : "N/A", style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        daysRemaining != null ? daysRemaining.toString() : "N/A",
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: daysRemaining != null && daysRemaining <= 3 ? PdfColors.red : PdfColors.black,
                          fontWeight: daysRemaining != null && daysRemaining <= 3 ? pw.FontWeight.bold : pw.FontWeight.normal,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        hasPoa ? "YES" : "NO",
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: hasPoa ? PdfColors.green900 : PdfColors.red900,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),

          pw.SizedBox(height: 24),

          // Escalated Notices
          if (escalatedNotices.isNotEmpty) ...[
            pw.Text(
              "ESCALATED NOTICES - IMMEDIATE ATTENTION REQUIRED",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
                color: PdfColors.red,
              ),
            ),
            pw.SizedBox(height: 12),

            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.red100),
              cellAlignment: pw.Alignment.centerLeft,
              headers: ["Notice ID", "Client", "Issue", "Due Date", "Days"],
              data: escalatedNotices.map((notice) {
                final client = clientMap[notice.clientId];
                final dueDate = notice.dueDate;
                final daysRemaining = dueDate != null
                    ? dueDate.difference(DateTime.now()).inDays
                    : null;

                return [
                  notice.autoId ?? notice.noticeNumber,
                  client?.name ?? notice.clientId,
                  notice.noticeIssue ?? "N/A",
                  dueDate != null ? dateFormat.format(dueDate) : "N/A",
                  daysRemaining != null ? daysRemaining.toString() : "N/A",
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 24),
          ],

          // Missing POA Notices
          if (missingPoaNotices.isNotEmpty) ...[
            pw.Text(
              "NOTICES MISSING POA COVERAGE",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 12),

            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.orange100),
              cellAlignment: pw.Alignment.centerLeft,
              headers: ["Notice ID", "Client", "Form", "Period", "Status"],
              data: missingPoaNotices.take(10).map((notice) {
                final client = clientMap[notice.clientId];

                return [
                  notice.autoId ?? notice.noticeNumber,
                  client?.name ?? notice.clientId,
                  notice.formNumber ?? "N/A",
                  notice.taxPeriod ?? "N/A",
                  notice.status,
                ];
              }).toList(),
            ),
          ],

          // Footer
          pw.SizedBox(height: 32),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "Page 1 of 1",
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
              pw.Text(
                "Confidential - Internal Use Only",
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.TableRow _buildTableRow(
      String label,
      String value, {
        bool isHeader = false,
        bool isTotal = false,
        bool isEscalated = false,
        bool isMissing = false,
        bool isMoney = false,
      }) {
    final bgColor = isHeader
        ? PdfColors.blue100
        : isTotal
        ? PdfColors.grey300
        : isEscalated
        ? PdfColors.red50
        : isMissing
        ? PdfColors.orange50
        : null;

    final textColor = isEscalated
        ? PdfColors.red900
        : isMissing
        ? PdfColors.orange900
        : isMoney
        ? PdfColors.green900
        : PdfColors.black;

    final fontWeight = isHeader || isTotal
        ? pw.FontWeight.bold
        : pw.FontWeight.normal;

    return pw.TableRow(
      decoration: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: fontWeight,
              color: textColor,
              fontSize: 11,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontWeight: fontWeight,
              color: textColor,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}