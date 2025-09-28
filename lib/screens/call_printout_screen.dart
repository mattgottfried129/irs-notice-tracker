import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/call.dart';

class CallPrintoutScreen extends StatelessWidget {
  final Call call;
  const CallPrintoutScreen({super.key, required this.call});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Print Response")),
      body: PdfPreview(
        build: (format) => _generatePdf(format, call),
      ),
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format, Call call) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Firm Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      "TAX & BUSINESS SOLUTIONS",
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "CERTIFIED PUBLIC ACCOUNTANT & Co., LLC",
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              pw.Center(
                child: pw.Text(
                  "IRS RESPONSE NOTES SHEET",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Client Info
              _sectionHeader("Client Information"),
              _row("Client ID:", call.clientId,
                  "Date of Response:", "${call.date.month}/${call.date.day}/${call.date.year}"),
              _row("Notice ID:", call.noticeId, "Agent ID #:", call.agentId ?? "N/A"),
              pw.SizedBox(height: 15),

              // Call Info
              _sectionHeader("Call Information"),
              _row("Response Method:", call.responseMethod,
                  "IRS Line Called:", call.irsLine),
              _row("Call Duration:", "${call.durationMinutes} min",
                  "Billing Status:", call.billing),
              pw.SizedBox(height: 15),

              // Issues & Notes
              _sectionHeader("Issues Discussed"),
              pw.Text(call.issues ?? "None"),
              pw.SizedBox(height: 10),

              _sectionHeader("Notes"),
              pw.Text(call.notes ?? "None"),
              pw.SizedBox(height: 15),

              // Outcome & Billing
              _sectionHeader("Outcome"),
              pw.Text(call.outcome ?? "None"),
              pw.SizedBox(height: 10),

              _sectionHeader("Billing"),
              _row("Billable:", call.billable ? "Yes" : "No",
                  "Amount:", "\$${call.calculateBillableAmount([call]).toStringAsFixed(2)}"),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _row(String leftLabel, String leftValue,
      String rightLabel, String rightValue) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 1,
            child: pw.Text("$leftLabel $leftValue",
                style: pw.TextStyle(fontSize: 11)),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Text("$rightLabel $rightValue",
                style: pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          decoration: pw.TextDecoration.underline,
        ),
      ),
    );
  }
}
