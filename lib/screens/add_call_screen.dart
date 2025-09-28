import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call.dart';
import '../models/client.dart';
import '../models/notice.dart';
import '../services/client_service.dart';
import 'call_printout_screen.dart';

class AddCallScreen extends StatefulWidget {
  final String noticeId;
  final String clientId;
  final Call? call;

  const AddCallScreen({
    super.key,
    required this.noticeId,
    required this.clientId,
    this.call,
  });

  @override
  State<AddCallScreen> createState() => _AddCallScreenState();
}

class _AddCallScreenState extends State<AddCallScreen> {
  final _formKey = GlobalKey<FormState>();

  final _responseMethodController = TextEditingController();
  final _irsLineController = TextEditingController();
  final _agentIdController = TextEditingController();
  final _issuesController = TextEditingController();
  final _notesController = TextEditingController();
  final _outcomeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hourlyRateController = TextEditingController();

  // Time tracking fields
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _holdMinutes = 0;
  bool _useTimer = false;
  DateTime? _timerStart;

  // Timer duration for display
  Duration _timerDuration = Duration.zero;
  DateTime? _callDate; // Add call date field

  DateTime? _followUpDate;

  // Search queries
  String _noticeSearchQuery = '';
  String _clientSearchQuery = '';

  bool _billable = true;
  bool _isLoading = false;
  List<Client> _clients = [];
  List<Notice> _notices = [];
  String? _selectedClientId;
  String? _selectedNoticeId;

  // Filtered lists
  List<Notice> get _filteredNotices {
    if (_noticeSearchQuery.isEmpty) {
      return _notices.where((notice) =>
      _selectedClientId == null || notice.clientId == _selectedClientId).toList();
    }
    return _notices.where((notice) {
      final matchesSearch = (notice.autoId?.toLowerCase().contains(_noticeSearchQuery) ?? false) ||
          notice.noticeNumber.toLowerCase().contains(_noticeSearchQuery) ||
          (notice.noticeIssue?.toLowerCase().contains(_noticeSearchQuery) ?? false);
      final matchesClient = _selectedClientId == null || notice.clientId == _selectedClientId;
      return matchesSearch && matchesClient;
    }).toList();
  }

  List<Client> get _filteredClients {
    if (_clientSearchQuery.isEmpty) {
      return _clients;
    }
    return _clients.where((client) {
      return client.name.toLowerCase().contains(_clientSearchQuery) ||
          client.id.toLowerCase().contains(_clientSearchQuery);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.clientId.isNotEmpty ? widget.clientId : null;
    _selectedNoticeId = widget.noticeId.isNotEmpty ? widget.noticeId : null;
    _callDate = DateTime.now(); // Default to today

    _hourlyRateController.text = '250.0'; // default hourly rate

    _loadData();

    if (widget.call != null) {
      _populateFormFields();
    }
  }

  void _populateFormFields() {
    final call = widget.call!;
    _responseMethodController.text = call.responseMethod;
    _irsLineController.text = call.irsLine;
    _agentIdController.text = call.agentId ?? '';
    _issuesController.text = call.issues ?? '';
    _notesController.text = call.notes ?? '';
    _outcomeController.text = call.outcome ?? '';
    _descriptionController.text = call.description ?? '';
    _hourlyRateController.text = call.hourlyRate?.toString() ?? '250.0';
    _billable = call.billable;
    _selectedClientId = call.clientId;
    _selectedNoticeId = call.noticeId;
    _callDate = call.date; // Load existing call date

    // Convert duration back to times (approximate)
    final totalMinutes = call.durationMinutes;
    if (totalMinutes > 0) {
      _startTime = const TimeOfDay(hour: 9, minute: 0); // Default start
      _endTime = TimeOfDay(
        hour: (9 + (totalMinutes / 60).floor()) % 24,
        minute: totalMinutes % 60,
      );
    }

    if (call.toMap().containsKey('followUpDate') &&
        call.toMap()['followUpDate'] != null) {
      _followUpDate = (call.toMap()['followUpDate'] as Timestamp).toDate();
    }
  }

  Future<void> _loadData() async {
    try {
      final clients = await ClientService.getClients();
      final noticesSnapshot =
      await FirebaseFirestore.instance.collection('notices').get();

      final notices = noticesSnapshot.docs.map((doc) {
        final data = doc.data();
        return Notice.fromMap(data, doc.id);
      }).toList();

      setState(() {
        _clients = clients;
        _notices = notices;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  void _startTimer() {
    _timerStart = DateTime.now();
    _useTimer = true;

    // Update timer every second
    Stream.periodic(const Duration(seconds: 1), (i) => i).listen((i) {
      if (_useTimer && _timerStart != null && mounted) {
        setState(() {
          _timerDuration = DateTime.now().difference(_timerStart!);
        });
      }
    });
  }

  void _stopTimer() {
    if (_timerStart != null) {
      final endTime = DateTime.now();
      final duration = endTime.difference(_timerStart!);

      setState(() {
        _useTimer = false;
        _startTime = TimeOfDay.fromDateTime(_timerStart!);
        _endTime = TimeOfDay.fromDateTime(endTime);
        _timerDuration = duration;
      });
    }
  }

  int _calculateDurationMinutes() {
    if (_useTimer && _timerStart != null) {
      return _timerDuration.inMinutes;
    }

    if (_startTime != null && _endTime != null) {
      // Convert TimeOfDay to minutes since midnight
      final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
      final endMinutes = _endTime!.hour * 60 + _endTime!.minute;

      // Handle next day scenario
      final totalMinutes = endMinutes >= startMinutes
          ? endMinutes - startMinutes
          : (24 * 60) - startMinutes + endMinutes;

      // Subtract hold time
      return (totalMinutes - _holdMinutes).clamp(0, 24 * 60);
    }

    return 0;
  }

  @override
  void dispose() {
    _responseMethodController.dispose();
    _irsLineController.dispose();
    _agentIdController.dispose();
    _issuesController.dispose();
    _notesController.dispose();
    _outcomeController.dispose();
    _descriptionController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  bool get _needsFollowUpDate {
    final val = _outcomeController.text;
    return val.startsWith("Waiting") ||
        val == "Monitor Account" ||
        val == "Submit Documentation" ||
        val == "Follow-Up Call" ||
        val == "Other (Details in Notes)";
  }

  Future<void> _updateNoticeDueDate() async {
    if (_selectedNoticeId != null && _followUpDate != null) {
      try {
        // Get the current notice to check its structure
        final noticeDoc = await FirebaseFirestore.instance
            .collection('notices')
            .doc(_selectedNoticeId!)
            .get();

        if (noticeDoc.exists) {
          final data = noticeDoc.data()!;

          // Update multiple fields to ensure the due date is updated
          await FirebaseFirestore.instance
              .collection('notices')
              .doc(_selectedNoticeId!)
              .update({
            'responseDeadline': _followUpDate!.millisecondsSinceEpoch,
            'nextFollowUpDate': _followUpDate!.millisecondsSinceEpoch,
            'lastUpdated': FieldValue.serverTimestamp(),
            'updatedByFollowUp': true,
            // Update the computed due date fields
            'computedDueDate': _followUpDate!.millisecondsSinceEpoch,
          });

          debugPrint("✅ Updated notice $_selectedNoticeId due date to $_followUpDate");
        }
      } catch (e) {
        debugPrint("❌ Failed to update notice due date: $e");
      }
    }
  }

  Future<void> _saveCall({bool goToPrint = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_needsFollowUpDate && _followUpDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Follow-up date required for this outcome")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final call = Call(
        id: widget.call?.id,
        noticeId: _selectedNoticeId ?? widget.noticeId,
        clientId: _selectedClientId!,
        date: _callDate ?? DateTime.now(), // Use the selected call date
        responseMethod: _responseMethodController.text.trim(),
        irsLine: _irsLineController.text.trim(),
        agentId: _agentIdController.text.trim(),
        issues: _issuesController.text.trim(),
        notes: _notesController.text.trim(),
        outcome: _outcomeController.text.trim(),
        description: _descriptionController.text.trim(),
        durationMinutes: _calculateDurationMinutes(), // Use the calculated duration
        hourlyRate: double.tryParse(_hourlyRateController.text.trim()) ?? 250.0,
        billable: _billable,
        billing: widget.call?.billing ?? "Unbilled",
      );

      final callMap = call.toMap();
      if (_needsFollowUpDate && _followUpDate != null) {
        callMap['followUpDate'] = _followUpDate;
        callMap['responseDeadline'] = _followUpDate;
      }

      // Save the call first
      if (widget.call != null) {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(widget.call!.id)
            .update(callMap);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call updated successfully')),
        );
      } else {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(call.id)
            .set(callMap);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call logged successfully')),
        );
      }

      // Update notice due date if follow-up date is set
      if (_needsFollowUpDate && _followUpDate != null) {
        await _updateNoticeDueDate();
      }

      // Now update the notice status based on the outcome
      String newStatus = "Open";
      final outcome = _outcomeController.text.trim();

      if (outcome == "Resolved") {
        newStatus = "Closed";
      } else if (outcome == "Waiting on Client") {
        newStatus = "Waiting on Client";
      } else if (outcome == "Waiting on IRS") {
        newStatus = "Awaiting IRS Response";
      } else if (outcome == "Monitor Account" ||
          outcome == "Submit Documentation" ||
          outcome == "Follow-Up Call" ||
          outcome == "Other (Details in Notes)") {
        newStatus = "In Progress";
      }

      // Get the correct notice document ID
      final noticeDocId = _selectedNoticeId ?? widget.noticeId;

      if (noticeDocId.isEmpty) {
        throw Exception("Notice ID is missing – cannot update status");
      }

      try {
        // Update the notice status in Firestore
        await FirebaseFirestore.instance
            .collection('notices')
            .doc(noticeDocId)
            .update({'status': newStatus});

        debugPrint("✅ Updated notice $noticeDocId to status $newStatus");

        // Show success message for status update
        if (outcome == "Resolved") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notice $noticeDocId marked as Closed')),
          );
        }
      } catch (e) {
        debugPrint("❌ Failed to update notice $noticeDocId: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Warning: Could not update notice status: $e')),
        );
        // Don't rethrow - the call was saved successfully
      }

      if (goToPrint) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CallPrintoutScreen(call: call)),
        );
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving call: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildClientSelector() {
    return Container(
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
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
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
            height: 150,
            child: ListView.builder(
              itemCount: _filteredClients.length,
              itemBuilder: (context, index) {
                final client = _filteredClients[index];
                final isSelected = _selectedClientId == client.id;

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
                      _selectedClientId = client.id;
                      // Clear selected notice when client changes
                      if (_selectedNoticeId != null) {
                        final notice = _notices.firstWhere(
                              (n) => n.id == _selectedNoticeId,
                          orElse: () => _notices.first,
                        );
                        if (notice.clientId != client.id) {
                          _selectedNoticeId = null;
                        }
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Text(
                  "Select Notice",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedNoticeId = null;
                    });
                  },
                  child: const Text("Clear", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          // Search Field
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search notices...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (value) {
                setState(() {
                  _noticeSearchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Filtered Notice List
          Container(
            height: 200,
            child: _filteredNotices.isEmpty
                ? const Center(
              child: Text(
                "No notices found.\nSelect a client first.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _filteredNotices.length,
              itemBuilder: (context, index) {
                final notice = _filteredNotices[index];
                final isSelected = _selectedNoticeId == notice.id;

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Colors.blue.withOpacity(0.1),
                  title: Text(notice.autoId ?? "Unknown Notice"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Client: ${notice.clientId}"),
                      if (notice.noticeIssue != null)
                        Text(notice.noticeIssue!),
                    ],
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    setState(() {
                      _selectedNoticeId = notice.id;
                      _selectedClientId = notice.clientId;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.call == null ? "Log Response" : "Edit Response"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Selector
                if (widget.clientId.isEmpty) ...[
                  _buildClientSelector(),
                  const SizedBox(height: 16),
                ],

                // Notice Selector
                if (widget.noticeId.isEmpty) ...[
                  _buildNoticeSelector(),
                  const SizedBox(height: 16),
                ],

                // Show selected client/notice info
                if (widget.noticeId.isNotEmpty || widget.clientId.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.noticeId.isNotEmpty || _selectedNoticeId != null)
                            Text(
                              "Notice: ${widget.noticeId.isNotEmpty ? widget.noticeId : _selectedNoticeId}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          if (widget.clientId.isNotEmpty || _selectedClientId != null)
                            Text("Client: ${widget.clientId.isNotEmpty ? widget.clientId : _selectedClientId}"),
                        ],
                      ),
                    ),
                  ),
                if (widget.noticeId.isNotEmpty || widget.clientId.isNotEmpty)
                  const SizedBox(height: 16),

                // Call Date Field
                ListTile(
                  title: Text(_callDate == null
                      ? "Call Date: Today"
                      : "Call Date: ${_callDate!.toLocal().toString().split(' ')[0]}"),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _callDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)), // Allow today and past dates
                    );
                    if (picked != null) {
                      setState(() => _callDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _responseMethodController.text.isNotEmpty
                      ? _responseMethodController.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: "Response Method",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Phone Call', child: Text('Phone Call')),
                    DropdownMenuItem(value: 'Fax', child: Text('Fax')),
                    DropdownMenuItem(value: 'Mail', child: Text('Mail')),
                    DropdownMenuItem(value: 'e-services', child: Text('e-services')),
                    DropdownMenuItem(value: 'Research', child: Text('Research')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _responseMethodController.text = value ?? '';
                    });
                  },
                  validator: (value) =>
                  (value == null || value.isEmpty) ? "Please select a response method" : null,
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _irsLineController.text.isNotEmpty
                      ? _irsLineController.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: "IRS Line Called",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PPS', child: Text('Practitioner Priority Service (PPS)')),
                    DropdownMenuItem(value: 'Collections', child: Text('Collections')),
                    DropdownMenuItem(value: 'Examinations', child: Text('Examinations')),
                    DropdownMenuItem(value: 'Taxpayer Advocate', child: Text('Taxpayer Advocate')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _irsLineController.text = value ?? '';
                    });
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _agentIdController,
                  decoration: const InputDecoration(
                    labelText: "Agent ID",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Time Tracking Section
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
                              "Time Tracking",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Switch(
                              value: _useTimer,
                              onChanged: (value) {
                                setState(() {
                                  if (value) {
                                    _startTimer();
                                  } else {
                                    _stopTimer();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_useTimer) ...[
                          // Timer Display
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "Timer Running",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${_timerDuration.inHours.toString().padLeft(2, '0')}:${(_timerDuration.inMinutes % 60).toString().padLeft(2, '0')}:${(_timerDuration.inSeconds % 60).toString().padLeft(2, '0')}",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _stopTimer,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text("Stop Timer"),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Manual Time Entry
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _startTime ?? TimeOfDay.now(),
                                    );
                                    if (picked != null) {
                                      setState(() => _startTime = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: "Start Time",
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      _startTime?.format(context) ?? "Select time",
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _endTime ?? TimeOfDay.now(),
                                    );
                                    if (picked != null) {
                                      setState(() => _endTime = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: "End Time",
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      _endTime?.format(context) ?? "Select time",
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: _holdMinutes.toString(),
                            decoration: const InputDecoration(
                              labelText: "Hold Time (minutes)",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              _holdMinutes = int.tryParse(val) ?? 0;
                              setState(() {}); // Trigger recalculation
                            },
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Duration Display
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Total Duration:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "${_calculateDurationMinutes()} minutes",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: "Brief Description (for billing)",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _issuesController,
                  decoration: const InputDecoration(
                    labelText: "Issues Discussed",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
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
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _outcomeController.text.isNotEmpty
                      ? _outcomeController.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: "Outcome",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Resolved', child: Text('Resolved')),
                    DropdownMenuItem(
                        value: 'Waiting on Client',
                        child: Text('Waiting on Client')),
                    DropdownMenuItem(
                        value: 'Waiting on IRS', child: Text('Waiting on IRS')),
                    DropdownMenuItem(
                        value: 'Monitor Account',
                        child: Text('In Progress – Monitor Account')),
                    DropdownMenuItem(
                        value: 'Submit Documentation',
                        child: Text('In Progress – Submit Documentation')),
                    DropdownMenuItem(
                        value: 'Follow-Up Call',
                        child: Text('In Progress – Follow-Up Call')),
                    DropdownMenuItem(
                        value: 'Other (Details in Notes)',
                        child: Text('In Progress – Other (Details in Notes)')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _outcomeController.text = value ?? '';
                    });
                  },
                  validator: (value) =>
                  (value == null || value.isEmpty)
                      ? "Please select an outcome"
                      : null,
                ),
                const SizedBox(height: 16),

                if (_needsFollowUpDate) ...[
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _followUpDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _followUpDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Follow-Up Date (This will update the notice due date)",
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _followUpDate != null
                            ? _followUpDate!.toIso8601String().split("T")[0]
                            : "Select a date",
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Billing Information",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _hourlyRateController,
                          decoration: const InputDecoration(
                            labelText: "Hourly Rate (\$)",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text("Billable"),
                          subtitle: const Text("Should this call be billed?"),
                          value: _billable,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (value) =>
                              setState(() => _billable = value),
                        ),
                        if (_billable) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Estimated Amount:"),
                                Text(
                                  "\${_calculateAmount().toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _saveCall(goToPrint: false),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(widget.call == null
                            ? "Save Call"
                            : "Update Call"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text("Save & Print"),
                        onPressed: _isLoading
                            ? null
                            : () => _saveCall(goToPrint: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _calculateAmount() {
    final duration = _calculateDurationMinutes();
    final rate = double.tryParse(_hourlyRateController.text) ?? 250.0;
    final timeBasedAmount = (duration / 60.0) * rate;

    if (_responseMethodController.text.toLowerCase().contains('research')) {
      return _roundToNext5(timeBasedAmount);
    }

    if (duration >= 60) {
      return _roundToNext5(timeBasedAmount);
    } else {
      return 250.0;
    }
  }

  double _roundToNext5(double amount) {
    return (amount / 5).ceil() * 5.0;
  }
}