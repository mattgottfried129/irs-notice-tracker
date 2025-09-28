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

  // UNDO FUNCTION - Clear ONLY POA records
  Future<void> _undoPoaImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Delete POA Records'),
        content: const Text(
            'This will delete ALL POA records from the database.\n\n'
                'Your clients, notices, and calls will NOT be affected.\n\n'
                'Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Yes, Delete POAs Only'),
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

      _addToLog("🗑️ Starting POA cleanup...");

      // Delete ONLY POA records
      _addToLog("Deleting POA records...");
      final poaSnapshot = await firestore.collection('poaRecords').get();
      _addToLog("Found ${poaSnapshot.docs.length} POA records to delete");

      if (poaSnapshot.docs.isNotEmpty) {
        // Delete in batches to avoid timeout
        final docs = poaSnapshot.docs;
        for (int i = 0; i < docs.length; i += 450) {
          final batch = firestore.batch();
          final end = (i + 450 < docs.length) ? i + 450 : docs.length;

          for (int j = i; j < end; j++) {
            batch.delete(docs[j].reference);
          }

          await batch.commit();
          _addToLog("✅ Deleted batch ${(i ~/ 450) + 1} (${end - i} records)");
        }

        _addToLog("✅ All ${poaSnapshot.docs.length} POA records deleted");
      } else {
        _addToLog("ℹ️ No POA records found to delete");
      }

      _addToLog("🎉 POA cleanup completed!");
      _addToLog("Your clients, notices, and calls are still intact");

    } catch (e) {
      _addToLog("❌ Error during POA cleanup: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _importFromAssets() async {
    setState(() {
      _isLoading = true;
      _status = "Importing from assets...";
      _importLog.clear();
    });

    try {
      _addToLog("📂 Loading CSV from assets/poa_master.csv...");

      final csvContent = await rootBundle.loadString('assets/poa_master.csv');
      await _processCsvContent(csvContent);

    } catch (e) {
      _addToLog("❌ Error loading from assets: $e");
      _addToLog("Make sure you have assets/poa_master.csv in your project");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processCsvContent(String csvContent) async {
    try {
      _addToLog("📊 Processing CSV data...");

      // Split into lines and remove empty ones
      List<String> lines = csvContent
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        _addToLog("❌ CSV file is empty");
        return;
      }

      _addToLog("Found ${lines.length} lines in CSV");

      // Skip header line
      List<String> dataLines = lines.skip(1).toList();
      _addToLog("Processing ${dataLines.length} data rows...");

      // Group by client for better organization
      Map<String, List<Map<String, String>>> clientGroups = {};
      int validRows = 0;
      int errorRows = 0;

      for (int i = 0; i < dataLines.length; i++) {
        try {
          String line = dataLines[i].trim();
          if (line.isEmpty) continue;

          // Parse CSV line (handle commas in quotes)
          List<String> fields = _parseCsvLine(line);

          if (fields.length < 8) {
            _addToLog("⚠️ Row ${i + 2}: Only ${fields.length} fields, skipping");
            errorRows++;
            continue;
          }

          String clientId = fields[0].trim();
          if (clientId.isEmpty) {
            errorRows++;
            continue;
          }

          Map<String, String> record = {
            'clientId': clientId,
            'clientName': fields[1].trim(),
            'form': fields[2].trim(),
            'periodStart': fields[3].trim(),
            'periodEnd': fields[4].trim(),
            'electronicCopy': fields[5].trim(),
            'cafVerified': fields[6].trim(),
            'paperCopy': fields[7].trim(),
          };

          clientGroups.putIfAbsent(clientId, () => []).add(record);
          validRows++;

        } catch (e) {
          _addToLog("❌ Error processing row ${i + 2}: $e");
          errorRows++;
        }
      }

      _addToLog("📋 Parsed: $validRows valid rows, $errorRows errors");
      _addToLog("👥 Found ${clientGroups.length} unique clients");

      // Import to Firestore
      await _importToFirestore(clientGroups);

    } catch (e) {
      _addToLog("❌ Error processing CSV: $e");
    }
  }

  List<String> _parseCsvLine(String line) {
    List<String> fields = [];
    bool inQuotes = false;
    StringBuffer currentField = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      String char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(currentField.toString());
        currentField.clear();
      } else {
        currentField.write(char);
      }
    }

    fields.add(currentField.toString());
    return fields;
  }

  bool _parseYesNo(String? value) {
    if (value == null) return false;
    String v = value.toUpperCase().trim();
    return v == 'Y' || v == 'YES' || v == '1';
  }

  Future<void> _importToFirestore(Map<String, List<Map<String, String>>> clientGroups) async {
    try {
      _addToLog("💾 Starting Firestore import...");

      final firestore = FirebaseFirestore.instance;
      int clientsCreated = 0;
      int poasCreated = 0;
      int batchCount = 0;

      // Check existing clients
      final existingClientsSnapshot = await firestore.collection('clients').get();
      Set<String> existingClientIds = existingClientsSnapshot.docs
          .map((doc) => (doc.data()['id'] ?? '').toString().toUpperCase())
          .toSet();

      _addToLog("📚 Found ${existingClientIds.length} existing clients");

      var batch = firestore.batch();

      for (var entry in clientGroups.entries) {
        String clientId = entry.key;
        List<Map<String, String>> records = entry.value;

        // Create client if doesn't exist
        if (!existingClientIds.contains(clientId.toUpperCase())) {
          final clientDoc = firestore.collection('clients').doc();
          batch.set(clientDoc, {
            'id': clientId,
            'name': records.first['clientName'] ?? clientId,
            'email': '',
            'phone': '',
            'address': '',
          });
          clientsCreated++;
          batchCount++;
        }

        // Create POA records
        for (var record in records) {
          final poaDoc = firestore.collection('poaRecords').doc();
          batch.set(poaDoc, {
            'clientId': record['clientId'],
            'clientName': record['clientName'],
            'form': record['form'],
            'periodStart': record['periodStart'],
            'periodEnd': record['periodEnd'],
            'electronicCopy': _parseYesNo(record['electronicCopy']),
            'cafVerified': _parseYesNo(record['cafVerified']),
            'paperCopy': _parseYesNo(record['paperCopy']),
          });
          poasCreated++;
          batchCount++;

          // Commit batch every 450 operations
          if (batchCount >= 450) {
            _addToLog("💾 Committing batch ($batchCount operations)...");
            await batch.commit();
            batch = firestore.batch();
            batchCount = 0;
          }
        }
      }

      // Commit remaining operations
      if (batchCount > 0) {
        _addToLog("💾 Committing final batch ($batchCount operations)...");
        await batch.commit();
      }

      _addToLog("🎉 Import completed successfully!");
      _addToLog("📊 Created: $clientsCreated clients, $poasCreated POAs");

    } catch (e) {
      _addToLog("❌ Error importing to Firestore: $e");
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
            // Undo POAs button (orange, less scary)
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _undoPoaImport,
                icon: const Icon(Icons.undo, size: 28),
                label: const Text(
                  "🗑️ UNDO - DELETE POA RECORDS ONLY",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
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
                    onPressed: _isLoading ? null : _importFromAssets,
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Import CSV"),
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