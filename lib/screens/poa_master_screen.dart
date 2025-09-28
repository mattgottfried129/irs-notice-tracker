import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'poa_import_screen.dart';

class PoaMasterScreen extends StatefulWidget {
  const PoaMasterScreen({super.key});

  @override
  State<PoaMasterScreen> createState() => _PoaMasterScreenState();
}

class _PoaMasterScreenState extends State<PoaMasterScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("POA Master"),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: "Import POAs",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PoaImportScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Search by Client or Form",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('poaRecords')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final poas = snapshot.data?.docs ?? [];
                final filtered = poas.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final clientName =
                  (data['clientName'] ?? '').toString().toLowerCase();
                  final clientId =
                  (data['clientId'] ?? '').toString().toLowerCase();
                  final form = (data['form'] ?? '').toString().toLowerCase();

                  return clientName.contains(_searchQuery) ||
                      clientId.contains(_searchQuery) ||
                      form.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text("No matching POA records found"));
                }

                return ListView(
                  children: filtered.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(
                          "${data['clientName'] ?? 'Unknown'} (${data['clientId'] ?? 'N/A'})",
                        ),
                        subtitle: Text(
                          "Form: ${data['form'] ?? ''} | "
                              "Period: ${data['periodStart'] ?? ''}-${data['periodEnd'] ?? ''} | "
                              "Electronic: ${data['electronicCopy'] == true ? 'Yes' : 'No'} | "
                              "CAF: ${data['cafVerified'] == true ? 'Yes' : 'No'} | "
                              "Paper: ${data['paperCopy'] == true ? 'Yes' : 'No'}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddPoaScreen(editDoc: doc),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete POA'),
                                    content: Text(
                                        'Delete POA for ${data['clientName']} (${data['clientId']})?'),
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
                                  await FirebaseFirestore.instance
                                      .collection('poaRecords')
                                      .doc(doc.id)
                                      .delete();

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('POA deleted successfully')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPoaScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddPoaScreen extends StatefulWidget {
  final DocumentSnapshot? editDoc;
  const AddPoaScreen({super.key, this.editDoc});

  @override
  State<AddPoaScreen> createState() => _AddPoaScreenState();
}

class _AddPoaScreenState extends State<AddPoaScreen> {
  String? _selectedClientId;
  final _clientIdController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _formController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();

  bool _electronicCopy = false;
  bool _cafVerified = false;
  bool _paperCopy = false;

  bool _createClient = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editDoc != null) {
      final data = widget.editDoc!.data() as Map<String, dynamic>;
      _selectedClientId = data['clientId'];
      _clientIdController.text = data['clientId'] ?? '';
      _clientNameController.text = data['clientName'] ?? '';
      _formController.text = data['form'] ?? '';
      _startController.text = data['periodStart'] ?? '';
      _endController.text = data['periodEnd'] ?? '';
      _electronicCopy = data['electronicCopy'] ?? false;
      _cafVerified = data['cafVerified'] ?? false;
      _paperCopy = data['paperCopy'] ?? false;
    }
  }

  Future<void> _savePoa() async {
    setState(() => _isSaving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final clientId =
      _createClient ? _clientIdController.text.trim() : _selectedClientId;
      final clientName = _createClient
          ? _clientNameController.text.trim()
          : await _getClientName(clientId!);

      if (clientId == null || clientId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Client ID is required")),
        );
        setState(() => _isSaving = false);
        return;
      }

      if (_createClient) {
        await firestore.collection('clients').doc().set({
          'id': clientId,
          'name': clientName,
          'email': '',
          'phone': '',
          'address': '',
        });
      }

      final poaData = {
        'clientId': clientId,
        'clientName': clientName,
        'form': _formController.text.trim(),
        'periodStart': _startController.text.trim(),
        'periodEnd': _endController.text.trim(),
        'electronicCopy': _electronicCopy,
        'cafVerified': _cafVerified,
        'paperCopy': _paperCopy,
      };

      if (widget.editDoc != null) {
        await firestore
            .collection('poaRecords')
            .doc(widget.editDoc!.id)
            .update(poaData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('POA updated successfully')),
          );
        }
      } else {
        await firestore.collection('poaRecords').add(poaData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('POA created successfully')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error saving POA: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving POA: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<String> _getClientName(String clientId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('id', isEqualTo: clientId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        return data['name'] ?? clientId;
      }
    } catch (e) {
      print("Error getting client name: $e");
    }
    return clientId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.editDoc != null ? "Edit POA" : "Add POA")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            SwitchListTile(
              value: _createClient,
              onChanged: (val) => setState(() => _createClient = val),
              title: const Text("Create new client"),
            ),
            const SizedBox(height: 16),

            if (_createClient) ...[
              TextFormField(
                controller: _clientIdController,
                decoration: const InputDecoration(
                  labelText: "Client ID",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clientNameController,
                decoration: const InputDecoration(
                  labelText: "Client Name",
                  border: OutlineInputBorder(),
                ),
              ),
            ] else
              TypeAheadField<Map<String, String>>(
                suggestionsCallback: (pattern) async {
                  if (pattern.isEmpty) return [];

                  try {
                    final snapshot = await FirebaseFirestore.instance
                        .collection('clients')
                        .get();

                    final clients = snapshot.docs.map((doc) {
                      final data = doc.data();
                      return {
                        'id': (data['id'] ?? '').toString().trim(),
                        'name': (data['name'] ?? '').toString().trim(),
                      };
                    }).where((c) => c['id']!.isNotEmpty).toList();

                    return clients.where((c) =>
                    c['id']!.toLowerCase().contains(pattern.toLowerCase()) ||
                        c['name']!.toLowerCase().contains(pattern.toLowerCase())
                    ).toList();
                  } catch (e) {
                    print("Error searching clients: $e");
                    return <Map<String, String>>[];
                  }
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    title: Text(suggestion['name']!.isNotEmpty
                        ? suggestion['name']!
                        : suggestion['id']!),
                    subtitle: Text(suggestion['id']!),
                  );
                },
                onSelected: (suggestion) {
                  setState(() {
                    _selectedClientId = suggestion['id'];
                  });
                },
                builder: (context, controller, focusNode) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: "Select Client",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),
            TextFormField(
              controller: _formController,
              decoration: const InputDecoration(
                labelText: "Form (e.g., 1040, 2848, 941)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _startController,
              decoration: const InputDecoration(
                labelText: "Period Start (e.g., 2022, Q1/2022)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _endController,
              decoration: const InputDecoration(
                labelText: "Period End (e.g., 2027, Q4/2027)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            CheckboxListTile(
              title: const Text("Electronic Copy"),
              value: _electronicCopy,
              onChanged: (val) =>
                  setState(() => _electronicCopy = val ?? false),
            ),
            CheckboxListTile(
              title: const Text("CAF Verified"),
              value: _cafVerified,
              onChanged: (val) => setState(() => _cafVerified = val ?? false),
            ),
            CheckboxListTile(
              title: const Text("Paper Copy"),
              value: _paperCopy,
              onChanged: (val) => setState(() => _paperCopy = val ?? false),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isSaving ? null : _savePoa,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : Text(widget.editDoc != null ? "Update POA" : "Save POA"),
            ),
          ],
        ),
      ),
    );
  }
}