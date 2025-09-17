import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/notice.dart';

class AddNoticeScreen extends StatefulWidget {
  final String clientId;

  const AddNoticeScreen({super.key, required this.clientId});

  @override
  State<AddNoticeScreen> createState() => _AddNoticeScreenState();
}

class _AddNoticeScreenState extends State<AddNoticeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _noticeNumberController = TextEditingController();
  final _periodController = TextEditingController();
  final _issueController = TextEditingController();
  DateTime? _dateReceived;
  DateTime? _dueDate;

  Future<void> _saveNotice() async {
    if (!_formKey.currentState!.validate()) return;

    final noticesBox = Hive.box<Notice>('notices');
    final newNotice = Notice(
      id: DateTime.now().millisecondsSinceEpoch, // unique ID
      clientId: widget.clientId,
      noticeNumber: _noticeNumberController.text.trim(),
      period: _periodController.text.trim(),
      dateReceived: _dateReceived ?? DateTime.now(),
      dueDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      poaOnFile: false, // will be calculated later
      status: "Open",
      calls: [],
      issue: _issueController.text.trim(), // 👈 NEW FIELD
    );

    await noticesBox.add(newNotice);
    if (!mounted) return;
    Navigator.pop(context, newNotice);
  }

  Future<void> _pickDate(BuildContext context, bool isDueDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = picked;
        } else {
          _dateReceived = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Notice")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _noticeNumberController,
                decoration: const InputDecoration(labelText: "Notice Number"),
                validator: (v) =>
                v == null || v.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _periodController,
                decoration: const InputDecoration(labelText: "Notice Period"),
              ),
              TextFormField(
                controller: _issueController,
                decoration: const InputDecoration(labelText: "Notice Issue"),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dateReceived == null
                          ? "Date Received: Not set"
                          : "Date Received: ${_dateReceived!.toLocal().toString().split(' ')[0]}",
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickDate(context, false),
                    child: const Text("Pick"),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dueDate == null
                          ? "Due Date: Not set"
                          : "Due Date: ${_dueDate!.toLocal().toString().split(' ')[0]}",
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickDate(context, true),
                    child: const Text("Pick"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveNotice,
                child: const Text("Save Notice"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
