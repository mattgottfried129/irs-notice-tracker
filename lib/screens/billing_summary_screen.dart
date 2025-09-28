import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call.dart';
import '../models/client.dart';
import '../services/client_service.dart';
import 'add_call_screen.dart';
import 'call_detail_screen.dart';

class BillingSummaryScreen extends StatefulWidget {
  const BillingSummaryScreen({super.key});

  @override
  State<BillingSummaryScreen> createState() => _BillingSummaryScreenState();
}

class _BillingSummaryScreenState extends State<BillingSummaryScreen> {
  String _selectedView = 'summary'; // summary, by_client, unbilled

  Future<Map<String, Client>> _getClientsMap() async {
    try {
      final clients = await ClientService.getClients();
      return {for (var client in clients) client.id: client};
    } catch (e) {
      print('Error loading clients: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Billing Management"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedView = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'summary',
                child: Text('Summary View'),
              ),
              const PopupMenuItem(
                value: 'by_client',
                child: Text('By Client'),
              ),
              const PopupMenuItem(
                value: 'unbilled',
                child: Text('Unbilled Calls'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCallScreen(noticeId: '', clientId: ''),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('calls').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final calls = snapshot.data?.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Call.fromMap(data, doc.id);
          }).toList() ??
              [];

          return FutureBuilder<Map<String, Client>>(
            future: _getClientsMap(),
            builder: (context, clientSnapshot) {
              final clientsMap = clientSnapshot.data ?? {};

              switch (_selectedView) {
                case 'by_client':
                  return _buildClientView(calls, clientsMap);
                case 'unbilled':
                  return _buildUnbilledView(calls, clientsMap);
                default:
                  return _buildSummaryView(calls, clientsMap);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryView(List<Call> calls, Map<String, Client> clientsMap) {
    final billed = calls.where((c) => c.billing == "Billed").toList();
    final unbilled = calls.where((c) => c.billing == "Unbilled").toList();

    final totalBillableMinutes = calls
        .where((c) => c.billable)
        .fold<int>(0, (sum, call) => sum + call.durationMinutes);

    final unbilledAmount = unbilled
        .where((c) => c.billable)
        .fold<double>(0, (sum, call) => sum + _calculateCallAmount(call));

    final billedAmount = billed
        .where((c) => c.billable)
        .fold<double>(0, (sum, call) => sum + _calculateCallAmount(call));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  "Total Calls",
                  calls.length.toString(),
                  Icons.call,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  "Billable Hours",
                  "${(totalBillableMinutes / 60.0).toStringAsFixed(1)}h",
                  Icons.access_time,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  "Unbilled",
                  "\$${unbilledAmount.toStringAsFixed(2)}",
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  "Billed Revenue",
                  "\$${billedAmount.toStringAsFixed(2)}",
                  Icons.monetization_on,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Unbilled Calls
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
                        "Recent Unbilled Calls",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedView = 'unbilled';
                          });
                        },
                        child: const Text("View All"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (unbilled.isEmpty)
                    const Text("No unbilled calls")
                  else
                    ...unbilled
                        .take(5)
                        .map((call) => _buildCallTile(call, clientsMap)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientView(List<Call> calls, Map<String, Client> clientsMap) {
    // Group calls by client
    final Map<String, List<Call>> callsByClient = {};
    for (final call in calls) {
      callsByClient.putIfAbsent(call.clientId, () => []).add(call);
    }

    // Calculate totals per client
    final clientTotals = <String, Map<String, double>>{};
    for (final entry in callsByClient.entries) {
      final clientId = entry.key;
      final clientCalls = entry.value;

      final billedCalls =
      clientCalls.where((c) => c.billing == "Billed" && c.billable);
      final unbilledCalls =
      clientCalls.where((c) => c.billing == "Unbilled" && c.billable);

      clientTotals[clientId] = {
        'billed': billedCalls.fold<double>(
            0, (sum, call) => sum + _calculateCallAmount(call)),
        'unbilled': unbilledCalls.fold<double>(
            0, (sum, call) => sum + _calculateCallAmount(call)),
        'total': clientCalls
            .where((c) => c.billable)
            .fold<double>(0, (sum, call) => sum + _calculateCallAmount(call)),
      };
    }

    // Sort clients by total amount (highest first)
    final sortedClients = clientTotals.entries.toList()
      ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text(
            "Client Billing Totals",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ...sortedClients.map((entry) {
            final clientId = entry.key;
            final totals = entry.value;
            final client = clientsMap[clientId];

            return Card(
              child: ListTile(
                title: Text(client?.name ?? 'Unknown Client'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Client ID: $clientId"),
                    Text("Calls: ${callsByClient[clientId]?.length ?? 0}"),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "\$${totals['total']!.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (totals['unbilled']! > 0)
                      Text(
                        "\$${totals['unbilled']!.toStringAsFixed(2)} unbilled",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  // Navigate to client detail - you can implement this later
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUnbilledView(List<Call> calls, Map<String, Client> clientsMap) {
    final unbilled = calls.where((c) => c.billing == "Unbilled").toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Most recent first

    final unbilledAmount = unbilled
        .where((c) => c.billable)
        .fold<double>(0, (sum, call) => sum + _calculateCallAmount(call));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Unbilled Calls (${unbilled.length})",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "\$${unbilledAmount.toStringAsFixed(2)}",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (unbilled.isNotEmpty)
                        ElevatedButton(
                          onPressed: () => _markAllAsBilled(unbilled),
                          child: const Text("Mark All Billed"),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (unbilled.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("No unbilled calls"),
              ),
            )
          else
            ...unbilled.map(
                    (call) => _buildCallTile(call, clientsMap, showActions: true)),
        ],
      ),
    );
  }

  Widget _buildCallTile(Call call, Map<String, Client> clientsMap,
      {bool showActions = false}) {
    final client = clientsMap[call.clientId];
    final amount = _calculateCallAmount(call);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: call.billable ? Colors.green : Colors.grey,
          child: const Icon(Icons.call, color: Colors.white),
        ),
        title: Text(client?.name ?? 'Unknown Client'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Notice: ${call.noticeId}"),
            Text("Date: ${_formatDate(call.date)}"),
            Text(
                "${call.durationMinutes} min ${call.billable ? '(Billable)' : '(Non-billable)'}"),
            if (call.description != null && call.description!.isNotEmpty)
              Text(call.description!,
                  style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (call.billable)
              Text(
                "\$${amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            if (showActions)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'bill':
                      await _markCallAsBilled(call);
                      break;
                    case 'edit':
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
                      break;
                    case 'view':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallDetailScreen(call: call),
                        ),
                      );
                      break;
                    case 'delete':
                      await _deleteCall(call);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'bill',
                    child: Text('Mark as Billed'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Call'),
                  ),
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('View Details'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red, size: 20),
                      title: Text('Delete Call'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
          ],
        ),
        onTap: showActions
            ? null
            : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallDetailScreen(call: call),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to format date safely
  String _formatDate(DateTime date) {
    return "${date.month}/${date.day}/${date.year}";
  }

  // Calculate amount using your billing logic
  double _calculateCallAmount(Call call) {
    if (!call.billable) return 0.0;

    final rate = call.hourlyRate ?? 250.0;
    final timeBasedAmount = (call.durationMinutes / 60.0) * rate;

    // For research calls, use actual time
    if (call.responseMethod.toLowerCase().contains('research')) {
      return _roundToNext5(timeBasedAmount);
    }

    // For non-research, apply minimum logic (simplified for display)
    if (call.durationMinutes >= 60) {
      return _roundToNext5(timeBasedAmount);
    } else {
      return 250.0; // Show minimum fee
    }
  }

  double _roundToNext5(double amount) {
    return (amount / 5).ceil() * 5.0;
  }

  Future<void> _markCallAsBilled(Call call) async {
    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(call.id)
          .update({'billing': 'Billed'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call marked as billed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating call: $e')),
      );
    }
  }

  Future<void> _deleteCall(Call call) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Call'),
        content: Text(
            'Are you sure you want to delete this call?\n\nClient: ${call.clientId}\nNotice: ${call.noticeId}\nDate: ${_formatDate(call.date)}\n\nThis action cannot be undone.'),
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
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(call.id)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting call: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsBilled(List<Call> calls) async {
    final totalAmount = calls
        .where((c) => c.billable)
        .fold<double>(0, (sum, call) => sum + _calculateCallAmount(call));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All as Billed'),
        content: Text(
            'Mark ${calls.length} calls as billed for \$${totalAmount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark All Billed'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final call in calls) {
          final docRef =
          FirebaseFirestore.instance.collection('calls').doc(call.id);
          batch.update(docRef, {'billing': 'Billed'});
        }
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${calls.length} calls marked as billed')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating calls: $e')),
        );
      }
    }
  }
}