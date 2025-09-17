import 'package:flutter/material.dart';
import '../models/call.dart';

class CallDetailScreen extends StatelessWidget {
  final Call call;

  const CallDetailScreen({super.key, required this.call});

  @override
  Widget build(BuildContext context) {
    final rawMinutes = call.rawDuration.inMinutes;
    final billedMinutes = call.duration.inMinutes;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Call Details"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              "IRS Line: ${call.irsLine}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("Agent: ${call.agentName} (ID: ${call.agentId})"),
            const SizedBox(height: 16),

            /// Date + Times
            Text("Call Date: ${call.callDate.toLocal().toString().split(' ')[0]}"),
            Text("Start Time: ${TimeOfDay.fromDateTime(call.startTime).format(context)}"),
            Text("End Time: ${TimeOfDay.fromDateTime(call.endTime).format(context)}"),
            const SizedBox(height: 8),

            /// Durations
            Text("Raw Duration: $rawMinutes minutes"),
            Text("Hold Time: ${call.holdMinutes} minutes"),
            Text(
              "Billable Duration: $billedMinutes minutes",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            /// Billing
            if (call.billed) ...[
              Text("Billed Hours: ${call.billedHours.toStringAsFixed(2)}"),
              Text(
                "Bill Amount: \$${call.billAmount.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ] else
              const Text("This call is not billable."),

            const SizedBox(height: 16),
            const Text(
              "Notes:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(call.notes),
          ],
        ),
      ),
    );
  }
}
