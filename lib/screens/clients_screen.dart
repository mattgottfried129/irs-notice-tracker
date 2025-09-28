import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client.dart';
import '../models/call.dart';
import '../services/client_service.dart';
import 'client_detail_screen.dart';
import 'add_client_screen.dart';
import 'add_call_screen.dart';
import 'invoice_summary_screen.dart';

class ClientsScreen extends StatefulWidget {
  final void Function(Widget)? onOpenDetail;
  final String? filterText;

  const ClientsScreen({super.key, this.onOpenDetail, this.filterText});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Clients"),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              // Could add sorting options here
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clients')
            .orderBy('id')
            .snapshots(),
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
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          var clients = snapshot.data?.docs.map((doc) {
            return Client.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList() ?? [];

          // Optional filtering
          if (widget.filterText != null && widget.filterText!.isNotEmpty) {
            clients = clients.where((c) =>
            c.id.toLowerCase().contains(widget.filterText!.toLowerCase()) ||
                c.displayName.toLowerCase().contains(widget.filterText!.toLowerCase())
            ).toList();
          }

          if (clients.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No clients found. Tap + to add one."),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: client.isMarriedFiling ? Colors.purple : Colors.blue,
                    child: client.isMarriedFiling
                        ? const Icon(Icons.people, color: Colors.white)
                        : Text(
                      client.taxpayerName.isNotEmpty ? client.taxpayerName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(client.fullDisplayName), // "ClientID - Taxpayer & Spouse"
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (client.isMarriedFiling)
                        Row(
                          children: [
                            const Icon(Icons.people, size: 16, color: Colors.purple),
                            const SizedBox(width: 4),
                            const Text("Married Filing", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      if (client.email != null) Text("Email: ${client.email}"),
                      if (client.phone != null) Text("Phone: ${client.phone}"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.receipt_long, color: Colors.teal),
                        tooltip: "Generate Invoice",
                        onPressed: () async {
                          final callsSnapshot = await FirebaseFirestore.instance
                              .collection('calls')
                              .where('clientId', isEqualTo: client.id)
                              .get();

                          final clientCalls = callsSnapshot.docs
                              .map((doc) => Call.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientDetailScreen(client: client),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Colors.teal,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.person_add),
            label: 'Add Client',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddClientScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.add_call),
            label: 'Add Response',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddCallScreen(
                    noticeId: "",
                    clientId: "",
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}