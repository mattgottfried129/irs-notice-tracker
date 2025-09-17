import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/client.dart';
import '../models/notice.dart';
import '../models/call.dart';
import '../services/poa_master.dart';
import 'notice_detail_screen.dart';
import 'call_detail_screen.dart';
import 'add_notice_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final Client client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  List<Notice> _notices = [];
  List<Call> _calls = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final noticesBox = Hive.box<Notice>('notices');
    final callsBox = Hive.box<Call>('calls');

    final notices =
    noticesBox.values.where((n) => n.clientId == widget.client.id).toList();
    final calls = callsBox.values
        .where((c) => notices.any((n) => n.id == c.noticeId))
        .toList();

    setState(() {
      _notices = notices;
      _calls = calls;
    });
  }

  Future<void> _addNotice() async {
    final newNotice = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNoticeScreen(clientId: widget.client.id),
      ),
    );
    if (newNotice != null) {
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notice added successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.client.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: ListTile(
                  title: Text(widget.client.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Client ID: ${widget.client.id}"),
                      Text("Contact: ${widget.client.contact}"),
                      Text("Email: ${widget.client.email}"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text("Notices", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _notices.isEmpty
                  ? const Text("No notices for this client.")
                  : Column(
                children: _notices.map((n) {
                  final hasPoa = PoaMasterService.hasPoa(n.clientId);
                  return Card(
                    child: ListTile(
                      title: Text("Notice ${n.noticeNumber}"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Period: ${n.period} | Status: ${n.status}"),
                          Text("Client ID: ${n.clientId}"),
                          Text("POA on File: ${hasPoa ? "Yes" : "No"}"),
                          if (n.issue != null && n.issue!.isNotEmpty)
                            Text("Issue: ${n.issue}"),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NoticeDetailScreen(notice: n),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              Text("Calls", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _calls.isEmpty
                  ? const Text("No calls logged for this client.")
                  : Column(
                children: _calls.map((c) {
                  return Card(
                    child: ListTile(
                      title: Text("${c.irsLine} – ${c.agentName}"),
                      subtitle: Text(
                        "Date: ${c.callDate.toString().split(' ').first} | "
                            "Duration: ${c.duration.inMinutes} min",
                      ),
                      trailing: Text(
                        c.billed
                            ? "\$${c.billAmount.toStringAsFixed(2)}"
                            : "Unbilled",
                        style: TextStyle(
                            color: c.billed ? Colors.green : Colors.red),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallDetailScreen(call: c),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNotice,
        child: const Icon(Icons.add),
      ),
    );
  }
}
