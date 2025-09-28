import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../models/notice.dart';
import '../models/poa_record.dart';
import '../models/call.dart';
import '../services/notice_service.dart';
import 'add_notice_screen.dart';
import 'add_call_screen.dart';
import 'call_detail_screen.dart';

class NoticeDetailScreen extends StatelessWidget {
  final String noticeId;

  const NoticeDetailScreen({super.key, required this.noticeId});

  bool _coversPeriod(String start, String end, String period) {
    final startInt = int.tryParse(start);
    final endInt = int.tryParse(end);
    final periodInt = int.tryParse(period);

    if (startInt == null || endInt == null || periodInt == null) return false;

    return periodInt >= startInt && periodInt <= endInt;
  }

  Future<PoaRecord?> _findPOARecord(String clientId, String? form, String? period) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('poaRecords')
          .where('clientId', isEqualTo: clientId)
          .get();

      for (final doc in querySnapshot.docs) {
        final poa = PoaRecord.fromMap(doc.data(), doc.id);
        if (poa.form == (form ?? '') &&
            _coversPeriod(poa.periodStart, poa.periodEnd, period ?? '')) {
          return poa;
        }
      }
    } catch (e) {
      print('Error finding POA record: $e');
    }
    return null;
  }

  Stream<List<Call>> _getCallsForNotice() {
    return FirebaseFirestore.instance
        .collection('calls')
        .where('noticeId', isEqualTo: noticeId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Call.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  // Helper method to get priority color
  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'final/levy/lien':
        return Colors.deepOrange;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Helper method to get priority icon
  IconData _getPriorityIcon(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'final/levy/lien':
        return Icons.warning;
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.flag;
      case 'low':
        return Icons.flag_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithColor(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteNotice(BuildContext context, Notice notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: Text(
            'Are you sure you want to delete notice ${notice.autoId}?\n\nThis action cannot be undone.'),
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
        await NoticeService.deleteNotice(notice.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notice ${notice.autoId} deleted successfully')),
        );
        Navigator.pop(context); // Go back
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('notices').doc(noticeId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final notice = Notice.fromMap(data, snapshot.data!.id);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Expanded(child: Text(notice.autoId ?? "Notice Details")),
                if (notice.priority != null) ...[
                  Icon(
                    _getPriorityIcon(notice.priority),
                    color: _getPriorityColor(notice.priority),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    notice.priority!,
                    style: TextStyle(
                      color: _getPriorityColor(notice.priority),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddNoticeScreen(notice: notice),
                    ),
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'delete':
                      _confirmDeleteNotice(context, notice);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Delete Notice'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // Notice Information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Notice Information",
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        _buildDetailRow("Notice ID", notice.autoId ?? "N/A"),
                        _buildDetailRow("Client ID", notice.clientId),
                        _buildDetailRow("Notice Number", notice.noticeNumber),
                        _buildDetailRow("Status", notice.status),
                        if (notice.priority != null)
                          _buildDetailRowWithColor(
                            "Priority",
                            notice.priority!,
                            _getPriorityColor(notice.priority),
                          ),
                        if (notice.noticeIssue != null)
                          _buildDetailRow("Issue", notice.noticeIssue!),
                        if (notice.formNumber != null)
                          _buildDetailRow("Form", notice.formNumber!),
                        if (notice.taxPeriod != null)
                          _buildDetailRow("Period", notice.taxPeriod!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Dates & Timeline
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Dates & Timeline",
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        if (notice.dateReceived != null)
                          _buildDetailRow("Notice Date",
                              notice.dateReceived!.toLocal().toString().split(' ')[0]),
                        if (notice.daysToRespond != null)
                          _buildDetailRow("Days to Respond", notice.daysToRespond.toString()),
                        if (notice.dueDate != null)
                          _buildDetailRow("Due Date",
                              notice.dueDate!.toLocal().toString().split(' ')[0]),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('calls')
                              .where('noticeId', isEqualTo: notice.id)
                              .orderBy('date', descending: true)
                              .limit(1)
                              .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData || snap.data!.docs.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final doc = snap.data!.docs.first;
                            final deadline = (doc['responseDeadline'] as Timestamp?)?.toDate();
                            if (deadline == null) return const SizedBox.shrink();
                            return _buildDetailRow(
                              "Response Deadline",
                              deadline.toLocal().toString().split(' ')[0],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                if (notice.notes != null && notice.notes!.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Notes",
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 16),
                          Text(notice.notes!),
                        ],
                      ),
                    ),
                  ),
                if (notice.notes != null && notice.notes!.isNotEmpty)
                  const SizedBox(height: 16),

                // POA Coverage
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("POA Coverage",
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        FutureBuilder<PoaRecord?>(
                          future: _findPOARecord(
                              notice.clientId, notice.formNumber, notice.taxPeriod),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }
                            final poa = snapshot.data;
                            if (poa != null) {
                              return Row(
                                children: const [
                                  Icon(Icons.verified_user, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text("Valid POA Found",
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold)),
                                ],
                              );
                            } else {
                              return Row(
                                children: const [
                                  Icon(Icons.warning_amber, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text("No Valid POA Found",
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold)),
                                ],
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Calls
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Calls", style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        StreamBuilder<List<Call>>(
                          stream: _getCallsForNotice(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text("No calls for this notice.");
                            }

                            final calls = snapshot.data!;
                            return Column(
                              children: calls.map((c) {
                                return ListTile(
                                  title: Text(c.responseMethod),
                                  subtitle: Text(
                                      "${c.date.month}/${c.date.day}/${c.date.year} • ${c.durationMinutes} mins"),
                                  trailing: Text(
                                    c.billing,
                                    style: TextStyle(
                                      color: c.billing == "Billed"
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CallDetailScreen(call: c),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: SpeedDial(
            icon: Icons.add,
            activeIcon: Icons.close,
            backgroundColor: Colors.teal,
            children: [
              SpeedDialChild(
                child: const Icon(Icons.edit_document),
                label: 'Edit Notice',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddNoticeScreen(notice: notice),
                    ),
                  );
                },
              ),
              SpeedDialChild(
                child: const Icon(Icons.add_call),
                label: 'Add Call',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddCallScreen(
                        noticeId: notice.id,
                        clientId: notice.clientId,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}