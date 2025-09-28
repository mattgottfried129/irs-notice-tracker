import 'package:flutter/material.dart';
import '../models/call.dart';
import 'batch_print_screen.dart';
import 'package:intl/intl.dart';

class MultiSelectPrintScreen extends StatefulWidget {
  final List<Call> allCalls;
  const MultiSelectPrintScreen({super.key, required this.allCalls});

  @override
  State<MultiSelectPrintScreen> createState() => _MultiSelectPrintScreenState();
}

class _MultiSelectPrintScreenState extends State<MultiSelectPrintScreen> {
  final Set<String> _selectedIds = {};
  final dateFormat = DateFormat('MM/dd/yyyy');

  void _checkAll() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(widget.allCalls.map((c) => c.id));
    });
  }

  void _uncheckAll() {
    setState(() {
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Calls to Print"),
        actions: [
          IconButton(
            tooltip: "Check All",
            icon: const Icon(Icons.select_all),
            onPressed: _checkAll,
          ),
          IconButton(
            tooltip: "Uncheck All",
            icon: const Icon(Icons.deselect),
            onPressed: _uncheckAll,
          ),
          TextButton(
            onPressed: _selectedIds.isEmpty
                ? null
                : () {
              final selectedCalls = widget.allCalls
                  .where((c) => _selectedIds.contains(c.id))
                  .toList();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BatchPrintScreen(calls: selectedCalls),
                ),
              );
            },
            child: const Text(
              "Print",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: widget.allCalls.length,
        itemBuilder: (context, index) {
          final call = widget.allCalls[index];
          final isSelected = _selectedIds.contains(call.id);
          final amount = call.calculateBillableAmount(widget.allCalls);

          return CheckboxListTile(
            value: isSelected,
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  _selectedIds.add(call.id);
                } else {
                  _selectedIds.remove(call.id);
                }
              });
            },
            title: Text("Client: ${call.clientId} • Notice: ${call.noticeId}"),
            subtitle: Text(
              "${dateFormat.format(call.date)} • ${call.durationMinutes} mins • ${call.responseMethod}",
            ),
            secondary: Text("\$${amount.toStringAsFixed(2)}"),
          );
        },
      ),
    );
  }
}
