import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

class PoaImportScreen extends StatefulWidget {
  const PoaImportScreen({super.key});

  @override
  State<PoaImportScreen> createState() => _PoaImportScreenState();
}

class _PoaImportScreenState extends State<PoaImportScreen> {
  bool _isLoading = false;
  String _status = "Ready";
  List<String> _importLog = [];

  void _addToLog(String message) {
    setState(() {
      _importLog.add("${DateTime.now().toString().substring(11, 19)}: $message");
      _status = message;
    });
    print("POA Import: $message");
  }

  // UNDO FUNCTION - Clear all imported data
  Future<void> _undoImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Delete All Data'),
        content: const Text(
            'This will delete ALL clients and POA records from the database.\n\n'
                'This action cannot be undone!\n\n'
                'Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _importLog.clear();
    });

    try {
      final firestore = FirebaseFirestore.instance;

      _addToLog("🗑️ Starting cleanup...");

      // Delete all POA records
      _addToLog("Deleting POA records...");
      final poaSnapshot = await firestore.collection('poaRecords').get();
      _addToLog("Found ${poaSnapshot.docs.length} POA records to delete");

      if (poaSnapshot.docs.isNotEmpty) {
        final poaBatch = firestore.batch();
        for (var doc in poaSnapshot.docs) {
          poaBatch.delete(doc.reference);
        }
        await poaBatch.commit();
        _addToLog("✅ Deleted ${poaSnapshot.docs.length} POA records");
      }

      // Delete all clients
      _addToLog("Deleting clients...");
      final clientSnapshot = await firestore.collection('clients').get();
      _addToLog("Found ${clientSnapshot.docs.length} clients to delete");

      if (clientSnapshot.docs.isNotEmpty) {
        final clientBatch = firestore.batch();
        for (var doc in clientSnapshot.docs) {
          clientBatch.delete(doc.reference);
        }
        await clientBatch.commit();
        _addToLog("✅ Deleted ${clientSnapshot.docs.length} clients");
      }

      // Also delete notices if any
      _addToLog("Checking for notices to delete...");
      final noticeSnapshot = await firestore.collection('notices').get();
      if (noticeSnapshot.docs.isNotEmpty) {
        _addToLog("Found ${noticeSnapshot.docs.length} notices to delete");
        final noticeBatch = firestore.batch();
        for (var doc in noticeSnapshot.docs) {
          noticeBatch.delete(doc.reference);
        }
        await noticeBatch.commit();
        _addToLog("✅ Deleted ${noticeSnapshot.docs.length} notices");
      }

      // Also delete calls if any
      _addToLog("Checking for calls to delete...");
      final callSnapshot = await firestore.collection('calls').get();
      if (callSnapshot.docs.isNotEmpty) {
        _addToLog("Found ${callSnapshot.docs.length} calls to delete");
        final callBatch = firestore.batch();
        for (var doc in callSnapshot.docs) {
          callBatch.delete(doc.reference);
        }
        await callBatch.commit();
        _addToLog("✅ Deleted ${callSnapshot.docs.length} calls");
      }

      _addToLog("🎉 All data cleared successfully!");
      _addToLog("Database is now completely empty and ready for fresh import");

    } catch (e) {
      _addToLog("❌ Error during cleanup: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importPOAs() async {
    setState(() {
      _isLoading = true;
      _status = "Importing...";
      _importLog.clear();
    });

    try {
      _addToLog("📂 Loading POA data from assets...");

      // Load JSON from assets
      final jsonString = await rootBundle.loadString('assets/poa_master_firestore.json');
      final List<dynamic> data = json.decode(jsonString);

      _addToLog("📊 Found ${data.length} POA records to import");

      final batch = FirebaseFirestore.instance.batch();
      final poaCollection = FirebaseFirestore.instance.collection('poaRecords');

      int imported = 0;
      for (var item in data) {
        final docRef = poaCollection.doc();
        batch.set(docRef, Map<String, dynamic>.from(item));
        imported++;

        if (imported % 50 == 0) {
          _addToLog("📥 Processed $imported records...");
        }
      }

      _addToLog("💾 Committing to Firestore...");
      await batch.commit();

      _addToLog("✅ Successfully imported ${data.length} POAs");

    } catch (e) {
      _addToLog("❌ Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentData() async {
    setState(() {
      _isLoading = true;
      _importLog.clear();
    });

    try {
      _addToLog("🔍 Checking current database contents...");

      final firestore = FirebaseFirestore.instance;

      // Count POA records
      final poaSnapshot = await firestore.collection('poaRecords').get();
      _addToLog("POA Records: ${poaSnapshot.docs.length}");

      // Count clients
      final clientSnapshot = await firestore.collection('clients').get();
      _addToLog("Clients: ${clientSnapshot.docs.length}");

      // Count notices
      final noticeSnapshot = await firestore.collection('notices').get();
      _addToLog("Notices: ${noticeSnapshot.docs.length}");

      // Count calls
      final callSnapshot = await firestore.collection('calls').get();
      _addToLog("Calls: ${callSnapshot.docs.length}");

      _addToLog("📊 Database check complete");

    } catch (e) {
      _addToLog("❌ Error checking data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("POA Import & Management"),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big red undo button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _undoImport,
                icon: const Icon(Icons.delete_forever, size: 28),
                label: const Text(
                  "🚨 UNDO - DELETE ALL DATA",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Other action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _checkCurrentData,
                    icon: const Icon(Icons.search),
                    label: const Text("Check Data"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _importPOAs,
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Import POAs"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Status
            Text(
              "Status: $_status",
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 16),

            // Log
            Text(
              "Activity Log:",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: _isLoading
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Working..."),
                    ],
                  ),
                )
                    : _importLog.isEmpty
                    ? const Text("No activity yet")
                    : ListView.builder(
                  itemCount: _importLog.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _importLog[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}