import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/call.dart';
import '../models/notice.dart';

class AddCallScreen extends StatefulWidget {
  final Notice notice;

  const AddCallScreen({super.key, required this.notice});

  @override
  State<AddCallScreen> createState() => _AddCallScreenState();
}

class _AddCallScreenState extends State<AddCallScreen> {
  final _formKey = GlobalKey<FormState>();

  final _agentNameController = TextEditingController();
  final _agentIdController = TextEditingController();
  final _irsLineController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _callDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime =
  TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);
  int _holdMinutes = 0;
  bool _billed = true;

  Future<void> _saveCall() async {
    if (!_formKey.currentState!.validate()) return;

    final callsBox = Hive.box<Call>('calls');

    final startDateTime = DateTime(
      _callDate.year,
      _callDate.month,
      _callDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _callDate.year,
      _callDate.month,
      _callDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    final newCall = Call(
      id: DateTime.now().millisecondsSinceEpoch,
      noticeId: widget.notice.id,
      callDate: _callDate,
      irsLine: _irsLineController.text.trim(),
      agentName: _agentNameController.text.trim(),
      agentId: _agentIdController.text.trim(),
      startTime: startDateTime,
      endTime: endDateTime,
      holdMinutes: _holdMinutes,
      notes: _notesController.text.trim(),
      billed: _billed,
    );

    await callsBox.add(newCall);

    widget.notice.calls.add(newCall);
    await widget.notice.save();

    if (!mounted) return;
    Navigator.pop(context, newCall);
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _callDate,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _callDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Call – Notice ${widget.notice.noticeNumber}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _irsLineController,
                decoration: const InputDecoration(labelText: "IRS Line Called"),
                validator: (v) =>
                v == null || v.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: _agentNameController,
                decoration: const InputDecoration(labelText: "IRS Agent Name"),
              ),
              TextFormField(
                controller: _agentIdController,
                decoration: const InputDecoration(labelText: "IRS Agent ID"),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Call Date: ${_callDate.toLocal().toString().split(' ')[0]}",
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickDate(context),
                    child: const Text("Pick"),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text("Start: ${_startTime.format(context)}"),
                  ),
                  TextButton(
                    onPressed: () => _pickTime(context, true),
                    child: const Text("Pick"),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text("End: ${_endTime.format(context)}"),
                  ),
                  TextButton(
                    onPressed: () => _pickTime(context, false),
                    child: const Text("Pick"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text("Hold (min):"),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      setState(() {
                        if (_holdMinutes > 0) _holdMinutes -= 5;
                      });
                    },
                  ),
                  Text("$_holdMinutes"),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        _holdMinutes += 5;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: "Notes"),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text("Billable"),
                value: _billed,
                onChanged: (v) => setState(() => _billed = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveCall,
                child: const Text("Save Call"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
