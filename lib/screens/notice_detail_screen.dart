import 'package:flutter/material.dart';
import '../models/notice.dart';
import '../models/call.dart';
import 'add_call_screen.dart';
import 'call_detail_screen.dart';

class NoticeDetailScreen extends StatefulWidget {
  final Notice notice;

  const NoticeDetailScreen({super.key, required this.notice});

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  void _addCall() async {
    final newCall = await Navigator.push<Call>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCallScreen(notice: widget.notice),
      ),
    );

    if (newCall != null) {
      setState(() {
        widget.notice.calls.add(newCall);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;

    return Scaffold(
      appBar: AppBar(
        title: Text("Notice ${notice.noticeNumber}"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Client: ${notice.clientId}",
              style: const TextStyle(fontSize: 16)),
          Text("Period: ${notice.period}",
              style: const TextStyle(fontSize: 16)),
          Text("Status: ${notice.status}",
              style: const TextStyle(fontSize: 16)),
          Text("POA on File: ${notice.poaOnFile ? "Yes" : "No"}",
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          const Text("Calls",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...notice.calls.map((call) => ListTile(
            title: Text("${call.agentName} (${call.agentId})"),
            subtitle: Text(
                "Duration: ${call.duration.inMinutes}m | Billed: \$${call.billAmount.toStringAsFixed(2)}"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallDetailScreen(call: call),
                ),
              );
            },
          )),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addCall,
            icon: const Icon(Icons.add),
            label: const Text("Add Call"),
          ),
        ],
      ),
    );
  }
}
