import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/call.dart';

class BillingSummaryScreen extends StatelessWidget {
  const BillingSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calls = dummyCalls;

    final billedCalls = calls.where((c) => c.billed).toList();
    final unbilledCalls = calls.where((c) => !c.billed).toList();

    final totalBilled = billedCalls.fold<double>(0, (sum, c) => sum + c.billAmount);
    final totalUnbilled =
    unbilledCalls.fold<double>(0, (sum, c) => sum + c.billAmount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Billed Total: \$${totalBilled.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text("Unbilled Total: \$${totalUnbilled.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        const Text("Billed Calls",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ...billedCalls.map((c) => ListTile(
          title: Text("${c.agentName} (${c.agentId})"),
          subtitle: Text(
              "Duration: ${c.duration.inMinutes}m | Billed: \$${c.billAmount.toStringAsFixed(2)}"),
        )),
        const Divider(),
        const Text("Unbilled Calls",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ...unbilledCalls.map((c) => ListTile(
          title: Text("${c.agentName} (${c.agentId})"),
          subtitle: Text(
              "Duration: ${c.duration.inMinutes}m | Billed: \$${c.billAmount.toStringAsFixed(2)}"),
        )),
      ],
    );
  }
}
