import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/client.dart';
import '../models/notice.dart';
import '../models/call.dart';
import '../services/client_service.dart';
import 'add_notice_screen.dart';
import 'add_client_screen.dart';
import 'invoice_summary_screen.dart';
import 'notice_detail_screen.dart';

class ClientDetailScreen extends StatelessWidget {
  final Client client;

  const ClientDetailScreen({super.key, required this.client});

  Future<void> _deleteClient(BuildContext context) async {
    // First check if client has any notices or calls
    final noticesSnapshot = await FirebaseFirestore.instance
        .collection('notices')
        .where('clientId', isEqualTo: client.id)
        .get();

    final callsSnapshot = await FirebaseFirestore.instance
        .collection('calls')
        .where('clientId', isEqualTo: client.id)
        .get();

    final poaSnapshot = await FirebaseFirestore.instance
        .collection('poaRecords')
        .where('clientId', isEqualTo: client.id)
        .get();

    final hasNotices = noticesSnapshot.docs.isNotEmpty;
    final hasCalls = callsSnapshot.docs.isNotEmpty;
    final hasPOAs = poaSnapshot.docs.isNotEmpty;

    // Show confirmation dialog with warning about related data
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete ${client.fullDisplayName}?'),
            const SizedBox(height: 16),
            if (hasNotices || hasCalls || hasPOAs) ...[
              const Text(
                'WARNING: This client has related data that will also be deleted:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              if (hasNotices) Text('• ${noticesSnapshot.docs.length} notice(s)'),
              if (hasCalls) Text('• ${callsSnapshot.docs.length} call(s)'),
              if (hasPOAs) Text('• ${poaSnapshot.docs.length} POA record(s)'),
              const SizedBox(height: 16),
              const Text(
                'This action cannot be undone!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ] else ...[
              const Text('This client has no related notices, calls, or POA records.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Deleting client and related data...'),
              ],
            ),
          ),
        );

        // Delete all related data first
        final batch = FirebaseFirestore.instance.batch();

        // Delete notices
        for (final doc in noticesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Delete calls
        for (final doc in callsSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Delete POA records
        for (final doc in poaSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Delete client
        final clientDoc = await FirebaseFirestore.instance
            .collection('clients')
            .where('id', isEqualTo: client.id)
            .limit(1)
            .get();

        if (clientDoc.docs.isNotEmpty) {
          batch.delete(clientDoc.docs.first.reference);
        }

        // Commit all deletions
        await batch.commit();

        // Close loading dialog
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${client.fullDisplayName} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Go back to clients list
        Navigator.pop(context);
      } catch (e) {
        // Close loading dialog
        Navigator.pop(context);

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting client: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(client.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Client',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddClientScreen(client: client),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'delete':
                  _deleteClient(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete Client'),
                  contentPadding: EdgeInsets.zero,
                ),
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
                      'Client Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Client ID', client.id),
                    _buildDetailRow('Taxpayer Name', client.taxpayerName),
                    if (client.isMarriedFiling && client.spouseName != null)
                      _buildDetailRow('Spouse Name', client.spouseName!),
                    if (client.email != null) _buildDetailRow('Email', client.email!),
                    if (client.phone != null) _buildDetailRow('Phone', client.phone!),
                    if (client.address != null) _buildDetailRow('Address', client.address!),
                    _buildDetailRow(
                        'Filing Status',
                        client.isMarriedFiling ? 'Married Filing' : 'Single/Other'
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Notices Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notices',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('notices')
                          .where('clientId', isEqualTo: client.id)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text("No notices for this client.");
                        }

                        final notices = snapshot.data!.docs
                            .map((doc) => Notice.fromMap(
                            doc.data() as Map<String, dynamic>, doc.id))
                            .toList();

                        return Column(
                          children: notices
                              .map(
                                (n) => ListTile(
                              title: Text(n.autoId ?? n.noticeNumber ?? "Unknown"),
                              subtitle: Text("Status: ${n.status}"),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NoticeDetailScreen(noticeId: n.id),
                                  ),
                                );
                              },
                            ),
                          )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "invoiceBtn",
            onPressed: () async {
              final callsSnapshot = await FirebaseFirestore.instance
                  .collection('calls')
                  .where('clientId', isEqualTo: client.id)
                  .get();

              final clientCalls = callsSnapshot.docs
                  .map((doc) =>
                  Call.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                  .toList()
                  .cast<Call>();

              if (clientCalls.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("No calls found for ${client.displayName}")),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceSummaryScreen(
                    clientId: client.id,
                    calls: clientCalls,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text("Invoice"),
            backgroundColor: Colors.teal,
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "addNoticeBtn",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddNoticeScreen(clientId: client.id),
                ),
              );
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}