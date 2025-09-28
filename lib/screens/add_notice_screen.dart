import 'package:flutter/material.dart';
import '../models/notice.dart';
import '../models/client.dart';
import '../services/notice_service.dart';
import '../services/client_service.dart';
import 'add_client_screen.dart';

class AddNoticeScreen extends StatefulWidget {
  final String? clientId; // passed from client or notice list
  final Notice? notice; // for editing existing notice

  const AddNoticeScreen({super.key, this.clientId, this.notice});

  @override
  State<AddNoticeScreen> createState() => _AddNoticeScreenState();
}

class _AddNoticeScreenState extends State<AddNoticeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _noticeNumberController = TextEditingController();
  final _noticeIssueController = TextEditingController();
  final _noticeFormController = TextEditingController();
  final _noticePeriodController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _noticeDate;
  int? _daysToRespond;
  String? selectedClientId;
  String? _selectedPriority;
  String _clientSearchQuery = '';
  bool _isLoading = false;
  List<Client> _clients = [];

  // Filtered clients based on search query
  List<Client> get _filteredClients {
    if (_clientSearchQuery.isEmpty) {
      return _clients;
    }
    return _clients.where((client) {
      return client.name.toLowerCase().contains(_clientSearchQuery) ||
          client.id.toLowerCase().contains(_clientSearchQuery);
    }).toList();
  }

  // Priority options
  final List<String> _priorityOptions = [
    'Low',
    'Medium',
    'High',
    'Final/Levy/Lien',
  ];

  @override
  void initState() {
    super.initState();
    selectedClientId = widget.clientId ?? widget.notice?.clientId;
    _loadClients();

    if (widget.notice != null) {
      _populateFormFields();
    }
  }

  void _populateFormFields() {
    final notice = widget.notice!;
    _noticeNumberController.text = notice.noticeNumber;
    _noticeIssueController.text = notice.noticeIssue ?? '';
    _noticeFormController.text = notice.formNumber ?? '';
    _noticePeriodController.text = notice.taxPeriod ?? '';
    _notesController.text = notice.notes ?? '';
    _noticeDate = notice.dateReceived;
    _daysToRespond = notice.daysToRespond;
    _selectedPriority = notice.priority; // Load existing priority
  }

  Future<void> _loadClients() async {
    try {
      final clients = await ClientService.getClients();
      setState(() {
        _clients = clients;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading clients: $e')),
      );
    }
  }

  @override
  void dispose() {
    _noticeNumberController.dispose();
    _noticeIssueController.dispose();
    _noticeFormController.dispose();
    _noticePeriodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotice() async {
    if (!_formKey.currentState!.validate()) return;

    final clientId =
        widget.clientId ?? selectedClientId ?? widget.notice?.clientId;
    if (clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a client")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String autoId;

      if (widget.notice != null) {
        autoId = widget.notice!.autoId ?? widget.notice!.id;
      } else {
        autoId = await Notice.generateAutoIdForClient(clientId);
      }

      final notice = Notice(
        id: widget.notice?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        clientId: clientId,
        autoId: autoId,
        noticeNumber: _noticeNumberController.text.trim(),
        noticeIssue: _noticeIssueController.text.trim(),
        noticeForm: _noticeFormController.text.trim(),
        noticePeriod: _noticePeriodController.text.trim(),
        noticeDate: _noticeDate,
        daysToRespond: _daysToRespond,
        notes: _notesController.text.trim(),
        status: widget.notice?.status ?? 'Open',
        poaOnFile: widget.notice?.poaOnFile ?? false,
        priority: _selectedPriority, // Save priority
      );

      if (widget.notice != null) {
        await NoticeService.updateNotice(widget.notice!.id, notice);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notice $autoId updated successfully')),
        );
      } else {
        await NoticeService.addNotice(notice);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notice $autoId created successfully')),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving notice: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNotice() async {
    if (widget.notice == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: Text(
            'Are you sure you want to delete notice ${widget.notice!.autoId}?'),
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
        await NoticeService.deleteNotice(widget.notice!.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Notice ${widget.notice!.autoId} deleted successfully')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.notice == null ? "Add Notice" : "Edit Notice"),
        actions: widget.notice != null
            ? [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteNotice,
          ),
        ]
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (widget.clientId == null && widget.notice == null) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text(
                          "Select Client",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      // Add New Client Button
                      ListTile(
                        leading: const Icon(Icons.add, color: Colors.blue),
                        title: const Text("Add New Client"),
                        onTap: () async {
                          final newId = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddClientScreen(),
                            ),
                          );
                          if (newId != null) {
                            await _loadClients();
                            setState(() {
                              selectedClientId = newId;
                            });
                          }
                        },
                      ),
                      const Divider(),
                      // Search Field
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: "Search clients...",
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _clientSearchQuery = value.toLowerCase();
                            });
                          },
                        ),
                      ),
                      // Filtered Client List
                      Container(
                        height: 200,
                        child: ListView.builder(
                          itemCount: _filteredClients.length,
                          itemBuilder: (context, index) {
                            final client = _filteredClients[index];
                            final isSelected = selectedClientId == client.id;

                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.blue.withOpacity(0.1),
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? Colors.blue : Colors.grey,
                                child: Text(
                                  client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(client.name),
                              subtitle: Text("ID: ${client.id}"),
                              trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                              onTap: () {
                                setState(() {
                                  selectedClientId = client.id;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedClientId == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Please select a client",
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              if (widget.notice != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Notice ID: ${widget.notice!.autoId ?? widget.notice!.id}',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('Client: ${widget.notice!.clientId}',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),

              if (widget.notice != null) const SizedBox(height: 16),

              TextFormField(
                controller: _noticeNumberController,
                decoration: const InputDecoration(
                  labelText: "Notice Number",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noticeIssueController,
                decoration: const InputDecoration(
                  labelText: "Notice Issue",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noticeFormController,
                decoration: const InputDecoration(
                  labelText: "Form",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noticePeriodController,
                decoration: const InputDecoration(
                  labelText: "Period",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Priority Dropdown
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: "Priority",
                  border: OutlineInputBorder(),
                ),
                items: _priorityOptions.map((priority) {
                  return DropdownMenuItem<String>(
                    value: priority,
                    child: Text(priority),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPriority = value;
                  });
                },
                validator: (value) => value == null ? "Please select a priority" : null,
              ),
              const SizedBox(height: 16),

              ListTile(
                title: Text(_noticeDate == null
                    ? "Select Notice Date"
                    : "Notice Date: ${_noticeDate!.toLocal().toString().split(' ')[0]}"),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _noticeDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _noticeDate = picked);
                  }
                },
              ),

              const SizedBox(height: 16),
              TextFormField(
                initialValue: _daysToRespond?.toString(),
                decoration: const InputDecoration(
                  labelText: "Days to Respond",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  _daysToRespond = int.tryParse(val);
                },
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: "Notes",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveNotice,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.notice == null
                    ? "Save Notice"
                    : "Update Notice"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}