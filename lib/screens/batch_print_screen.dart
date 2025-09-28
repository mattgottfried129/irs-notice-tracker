import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/call.dart';

class BatchPrintScreen extends StatelessWidget {
  final List<Call> calls;
  const BatchPrintScreen({super.key, required this.calls});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Batch Print Responses")),
      body: PdfPreview(
        build: (format) => _generateBatchPdf(format, calls),
      ),
    );
  }

  Future<Uint8List> _generateBatchPdf(
      PdfPageFormat format, List<Call> calls) async {
    final pdf = pw.Document();

    for (final call in calls) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return _buildCallPage(call);
          },
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _buildCallPage(Call call) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            "TAX & BUSINESS SOLUTIONS\nCERTIFIED PUBLIC ACCOUNTANT & Co., LLC",
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            "IRS RESPONSE NOTES SHEET",
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
        pw.SizedBox(height: 20),

        _row("Client ID:", call.clientId,
            "Date of Response:", "${call.date.month}/${call.date.day}/${call.date.year}"),
        _row("Notice ID:", call.noticeId, "Agent ID #:", call.agentId ?? "N/A"),
        pw.SizedBox(height: 10),

        _row("Response Method:", call.responseMethod,
            "IRS Line Called:", call.irsLine),
        _row("Call Duration:", "${call.durationMinutes} min",
            "Billing Status:", call.billing),
        _row("Bill Amount:",
            "\$${call.calculateBillableAmount([call]).toStringAsFixed(2)}",
            "", ""),
        pw.SizedBox(height: 15),

        pw.Text("Issues Discussed: ${call.issues ?? ''}"),
        pw.SizedBox(height: 10),
        pw.Text("Notes: ${call.notes ?? ''}"),
        pw.SizedBox(height: 10),
        pw.Text("Outcome: ${call.outcome ?? ''}"),
      ],
    );
  }

  pw.Widget _row(String leftLabel, String leftValue,
      String rightLabel, String rightValue) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          flex: 1,
          child: pw.Text("$leftLabel $leftValue",
              style: const pw.TextStyle(fontSize: 11)),
        ),
        pw.Expanded(
          flex: 1,
          child: pw.Text("$rightLabel $rightValue",
              style: const pw.TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}
