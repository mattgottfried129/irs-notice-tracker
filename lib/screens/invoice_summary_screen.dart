import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/call.dart';

class InvoiceSummaryScreen extends StatelessWidget {
  final String clientId;
  final List<Call> calls;
  const InvoiceSummaryScreen({super.key, required this.clientId, required this.calls});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Invoice Summary")),
      body: PdfPreview(
        build: (format) => _generatePdf(format, clientId, calls),
      ),
    );
  }

  Future<Uint8List> _generatePdf(
      PdfPageFormat format, String clientId, List<Call> calls) async {
    final pdf = pw.Document();

    // split calls
    final unbilledCalls = calls.where((c) => c.billing == "Unbilled").toList();
    final billedCalls = calls.where((c) => c.billing == "Billed").toList();

    final unbilledTotal = unbilledCalls.fold<double>(
      0.0,
          (sum, call) => sum + call.calculateBillableAmount(calls),
    );

    final billedTotal = billedCalls.fold<double>(
      0.0,
          (sum, call) => sum + call.calculateBillableAmount(calls),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Text(
                "TAX & BUSINESS SOLUTIONS\nCERTIFIED PUBLIC ACCOUNTANT & Co., LLC",
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Text("Invoice Summary for Client: $clientId",
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),

            // Unbilled Section
            pw.Text("Current Charges (Unbilled Calls)",
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 10),
            if (unbilledCalls.isEmpty)
              pw.Text("No unbilled calls."),
            if (unbilledCalls.isNotEmpty)
              pw.Table.fromTextArray(
                headers: ["Date", "Notice", "Method", "Minutes", "Amount"],
                data: unbilledCalls.map((c) {
                  final amount = c.calculateBillableAmount(calls);
                  return [
                    "${c.date.month}/${c.date.day}/${c.date.year}",
                    c.noticeId,
                    c.responseMethod,
                    "${c.durationMinutes}",
                    "\$${amount.toStringAsFixed(2)}",
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text("Unbilled Total: \$${unbilledTotal.toStringAsFixed(2)}",
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),

            // Billed Section
            pw.Text("Previously Billed Calls (For Reference)",
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 10),
            if (billedCalls.isEmpty)
              pw.Text("No billed calls."),
            if (billedCalls.isNotEmpty)
              pw.Table.fromTextArray(
                headers: ["Date", "Notice", "Method", "Minutes", "Amount"],
                data: billedCalls.map((c) {
                  final amount = c.calculateBillableAmount(calls);
                  return [
                    "${c.date.month}/${c.date.day}/${c.date.year}",
                    c.noticeId,
                    c.responseMethod,
                    "${c.durationMinutes}",
                    "\$${amount.toStringAsFixed(2)}",
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text("Previously Billed Total: \$${billedTotal.toStringAsFixed(2)}",
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }
}
