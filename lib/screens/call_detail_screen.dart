import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call.dart';
import '../models/client.dart';
import '../services/client_service.dart';
import 'call_printout_screen.dart';
import 'add_call_screen.dart';
import 'call_detail_screen.dart';

class CallDetailScreen extends StatelessWidget {
  final Call call;

  const CallDetailScreen({super.key, required this.call});

  Future<Client?> _getClientById(String clientId) async {
    try {
      final clients = await ClientService.getClients();
      // In _getClientById method, replace the Client creation:
      return clients.firstWhere(
            (c) => c.id == clientId,
        orElse: () => Client(id: clientId, taxpayerName: 'Unknown Client'), // Fix this line
      );
    } catch (e) {
      print('Error loading client: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Response Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCallScreen(
                    noticeId: call.noticeId,
                    clientId: call.clientId,
                    call: call,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Print Response",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallPrintoutScreen(call: call),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'bill':
                  await _toggleBillingStatus(context);
                  break;
                case 'delete':
                  await _deleteCall(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'bill',
                child: Text(
                  call.billing == 'Billed'
                      ? 'Mark as Unbilled'
                      : 'Mark as Billed',
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Response'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Client Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Client Information",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<Client?>(
                      future: _getClientById(call.clientId),
                      builder: (context, snapshot) {
                        final client = snapshot.data;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow("Client ID", call.clientId),
                            _buildDetailRow(
                                "Client Name", client?.name ?? 'Loading...'),
                            _buildDetailRow("Notice ID", call.noticeId),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Call Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Response Details",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                        "Date", call.date.toLocal().toString().split(' ')[0]),
                    _buildDetailRow("Response Method", call.responseMethod),
                    _buildDetailRow("IRS Line", call.irsLine),
                    if (call.agentId != null)
                      _buildDetailRow("Agent ID", call.agentId!),
                    _buildDetailRow(
                        "Duration", "${call.durationMinutes} minutes"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Call Notes Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Response Notes",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (call.description != null)
                      _buildDetailRow("Description", call.description!),
                    if (call.issues != null)
                      _buildDetailRow("Issues Discussed", call.issues!),
                    if (call.notes != null)
                      _buildDetailRow("Notes", call.notes!),
                    if (call.outcome != null)
                      _buildDetailRow("Outcome", call.outcome!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Billing Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Billing Information",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Chip(
                          label: Text(call.billing),
                          backgroundColor: call.billing == 'Billed'
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          labelStyle: TextStyle(
                            color: call.billing == 'Billed'
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow("Billable", call.billable ? "Yes" : "No"),
                    if (call.billable) ...[
                      _buildDetailRow(
                          "Duration", "${call.durationMinutes} minutes"),
                      _buildDetailRow("Hourly Rate",
                          "\$${call.hourlyRate?.toStringAsFixed(2) ?? '150.00'}"),
                      _buildDetailRow(
                        "Amount",
                        "\$${call.billableAmount.toStringAsFixed(2)}",
                        valueStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddCallScreen(
                            noticeId: call.noticeId,
                            clientId: call.clientId,
                            call: call,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Response"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallPrintoutScreen(call: call),
                        ),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("Print Response"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBillingStatus(BuildContext context) async {
    try {
      final newStatus = call.billing == 'Billed' ? 'Unbilled' : 'Billed';

      await FirebaseFirestore.instance
          .collection('calls')
          .doc(call.id)
          .update({'billing': newStatus});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call marked as $newStatus')),
      );

      // Refresh the screen by popping and pushing again (simple approach)
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating billing status: $e')),
      );
    }
  }

  Future<void> _deleteCall(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Call'),
        content: const Text(
            'Are you sure you want to delete this call?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        print('Attempting to delete call with ID: ${call.id}');

        // Verify the document exists before deleting
        final docRef =
            FirebaseFirestore.instance.collection('calls').doc(call.id);

        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
          print(
              'Warning: Document with ID ${call.id} does not exist in Firestore');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Call not found in database - it may have already been deleted'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context); // Go back anyway
          return;
        }

        await docRef.delete();
        print('Call deleted successfully from Firestore');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call deleted successfully')),
        );

        Navigator.pop(context); // Go back to previous screen
      } catch (e) {
        print('Error deleting call: $e');
        print('Call ID that failed to delete: ${call.id}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting call: $e')),
        );
      }
    }
  }
}
