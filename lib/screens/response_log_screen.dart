import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call.dart';
import 'package:intl/intl.dart';
import 'call_detail_screen.dart';
import 'batch_print_screen.dart';
import 'multi_select_print_screen.dart';
import 'invoice_summary_screen.dart';
import 'add_call_screen.dart';

class ResponseLogScreen extends StatelessWidget {
  const ResponseLogScreen({super.key});

  Stream<List<Call>> _getCallsStream() {
    return FirebaseFirestore.instance
        .collection('calls')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('📊 Response Log: Loading ${snapshot.docs.length} call documents');

      final calls = snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          print('📊 Parsing call ${doc.id}: ${data['responseMethod'] ?? 'Unknown'} on ${data['date']}');
          return Call.fromMap(data, doc.id);
        } catch (e) {
          print('❌ Error parsing call ${doc.id}: $e');
          print('❌ Call data: ${doc.data()}');
          return null;
        }
      }).whereType<Call>().toList();

      print('✅ Successfully parsed ${calls.length} calls');
      return calls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: StreamBuilder<List<Call>>(
        stream: _getCallsStream(),
        builder: (context, snapshot) {
          print('📊 StreamBuilder state: ${snapshot.connectionState}');
          print('📊 Has data: ${snapshot.hasData}');
          print('📊 Has error: ${snapshot.hasError}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            print('❌ StreamBuilder error: ${snapshot.error}');
            return Scaffold(
              appBar: AppBar(title: const Text("Response Log")),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading calls: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Force refresh by rebuilding widget
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text("Response Log")),
              body: const Center(child: Text("No calls logged")),
              floatingActionButton: FloatingActionButton.extended(
                heroTag: "addResponseBtn",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddCallScreen(
                        noticeId: "",
                        clientId: "",
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text("Add Response"),
              ),
            );
          }

          final allCalls = snapshot.data!;
          print('📊 Total calls loaded: ${allCalls.length}');

          final unbilledCalls =
          allCalls.where((c) => c.billing == "Unbilled").toList();
          final billedCalls =
          allCalls.where((c) => c.billing == "Billed").toList();

          print('📊 Unbilled: ${unbilledCalls.length}, Billed: ${billedCalls.length}');

          return Scaffold(
            appBar: AppBar(
              title: Text("Response Log (${allCalls.length} calls)"),
              bottom: TabBar(
                tabs: [
                  Tab(text: "Unbilled (${unbilledCalls.length})"),
                  Tab(text: "All Calls"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildUnbilledTab(unbilledCalls, allCalls),
                _buildAllCallsTab(allCalls, billedCalls, unbilledCalls),
              ],
            ),
            floatingActionButton: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: "addResponseBtn",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddCallScreen(
                          noticeId: "",
                          clientId: "",
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add Response"),
                ),
                const SizedBox(height: 10),

                FloatingActionButton.extended(
                  heroTag: "batchPrintBtn",
                  onPressed: () async {
                    final choice = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Batch Print Options"),
                          content: const Text("Choose which calls to include:"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, "unbilled"),
                              child: const Text("Unbilled Only"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, "all"),
                              child: const Text("All Calls"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, "custom"),
                              child: const Text("Select Calls"),
                            ),
                          ],
                        );
                      },
                    );

                    if (choice == "unbilled") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BatchPrintScreen(calls: unbilledCalls),
                        ),
                      );
                    } else if (choice == "all") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BatchPrintScreen(calls: allCalls),
                        ),
                      );
                    } else if (choice == "custom") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MultiSelectPrintScreen(allCalls: allCalls),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.print),
                  label: const Text("Batch Print"),
                ),
                const SizedBox(height: 10),

                FloatingActionButton.extended(
                  heroTag: "invoiceBtn",
                  onPressed: () async {
                    final clientIds = allCalls.map((c) => c.clientId).toSet().toList();

                    if (clientIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("No clients available for invoices")),
                      );
                      return;
                    }

                    final clientDocs = await FirebaseFirestore.instance
                        .collection('clients')
                        .where(FieldPath.documentId, whereIn: clientIds)
                        .get();

                    final clientMap = {
                      for (var doc in clientDocs.docs) doc.id: doc['name'] ?? doc.id
                    };

                    final selectedClient = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        return SimpleDialog(
                          title: const Text("Select Client for Invoice"),
                          children: clientIds.map((id) {
                            final name = clientMap[id] ?? id;
                            return SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, id),
                              child: Text(name),
                            );
                          }).toList(),
                        );
                      },
                    );

                    if (selectedClient != null) {
                      final clientCalls =
                      allCalls.where((c) => c.clientId == selectedClient).toList();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoiceSummaryScreen(
                            clientId: selectedClient,
                            calls: clientCalls,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text("Invoice Print"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnbilledTab(List<Call> unbilledCalls, List<Call> allCalls) {
    if (unbilledCalls.isEmpty) {
      return const Center(child: Text("No unbilled calls"));
    }

    final total = unbilledCalls.fold<double>(
        0.0, (sum, call) => sum + call.calculateBillableAmount(allCalls));

    return Column(
      children: [
        Container(
          color: Colors.grey.shade200,
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          child: Text(
            "Unbilled Total: \$${total.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(child: _buildCallList(unbilledCalls, allCalls)),
      ],
    );
  }

  Widget _buildAllCallsTab(
      List<Call> allCalls, List<Call> billedCalls, List<Call> unbilledCalls) {
    if (allCalls.isEmpty) {
      return const Center(child: Text("No calls logged"));
    }

    final billedTotal = billedCalls.fold<double>(
        0.0, (sum, call) => sum + call.calculateBillableAmount(allCalls));
    final unbilledTotal = unbilledCalls.fold<double>(
        0.0, (sum, call) => sum + call.calculateBillableAmount(allCalls));

    return Column(
      children: [
        Container(
          color: Colors.grey.shade200,
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Billed: \$${billedTotal.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Text(
                "Unbilled: \$${unbilledTotal.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildCallList(allCalls, allCalls)),
      ],
    );
  }

  Widget _buildCallList(List<Call> calls, List<Call> allCalls) {
    final dateFormat = DateFormat('MM/dd/yyyy');

    return ListView.builder(
      itemCount: calls.length,
      itemBuilder: (context, index) {
        final call = calls[index];
        final amount = call.calculateBillableAmount(allCalls);

        return Card(
          child: ListTile(
            title: Text("Client: ${call.clientId} • Notice: ${call.noticeId}"),
            subtitle: Text(
              "${dateFormat.format(call.date)} • ${call.durationMinutes} mins • ${call.responseMethod}",
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("\$${amount.toStringAsFixed(2)}"),
                Text(
                  call.billing,
                  style: TextStyle(
                    color: call.billing == "Billed" ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallDetailScreen(call: call),
                ),
              );
            },
          ),
        );
      },
    );
  }
}