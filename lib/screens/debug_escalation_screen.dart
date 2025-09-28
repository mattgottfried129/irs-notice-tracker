import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notice.dart';
import '../models/call.dart';
import '../services/notice_logic.dart';

class DebugEscalationScreen extends StatelessWidget {
  const DebugEscalationScreen({super.key});

  Future<Map<String, List<Call>>> _getAllCalls() async {
    final callsSnapshot = await FirebaseFirestore.instance.collection('calls').get();
    final calls = callsSnapshot.docs.map((doc) => Call.fromMap(doc.data(), doc.id)).toList();

    final Map<String, List<Call>> callsByNotice = {};
    for (final call in calls) {
      callsByNotice.putIfAbsent(call.noticeId, () => []).add(call);
    }
    return callsByNotice;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Debug Escalation Logic")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notices').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notices = snapshot.data!.docs
              .map((doc) => Notice.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          return FutureBuilder<Map<String, List<Call>>>(
            future: _getAllCalls(),
            builder: (context, callsSnapshot) {
              if (!callsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final callsByNotice = callsSnapshot.data!;

              // Show current date at top
              final now = DateTime.now();

              return ListView(
                children: [
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Date/Time: $now', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Date Only: ${now.toLocal().toString().split(' ')[0]}'),
                          Text('Timezone: ${now.timeZoneName}'),
                        ],
                      ),
                    ),
                  ),
                  ...notices.map((notice) {
                    final calls = callsByNotice[notice.id] ?? [];
                    final deadline = NoticeLogic.calculateResponseDeadline(notice, calls);
                    final daysRemaining = NoticeLogic.calculateDaysRemaining(notice, calls);
                    final isEscalated = NoticeLogic.isEscalated(notice, calls);
                    final calculatedStatus = NoticeLogic.calculateStatus(notice, calls);

                    // Color code based on escalation
                    Color cardColor = Colors.white;
                    if (isEscalated) {
                      cardColor = Colors.red.shade50;
                    } else if (daysRemaining != null && daysRemaining <= 7) {
                      cardColor = Colors.orange.shade50;
                    }

                    return Card(
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${notice.autoId ?? notice.id}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                if (isEscalated)
                                  const Icon(Icons.warning, color: Colors.red),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Current vs Calculated Status
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Current: ${notice.status}'),
                                      Text('Calculated: $calculatedStatus',
                                          style: TextStyle(
                                              color: calculatedStatus != notice.status ? Colors.red : Colors.black
                                          )),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(),

                            // Date Information
                            Text('Date Received: ${notice.dateReceived}'),
                            Text('Days to Respond: ${notice.daysToRespond}'),
                            Text('Calculated Deadline: $deadline'),
                            Text('Days Remaining: $daysRemaining',
                                style: TextStyle(
                                  color: daysRemaining != null && daysRemaining <= 3 ? Colors.red : Colors.black,
                                  fontWeight: daysRemaining != null && daysRemaining <= 3 ? FontWeight.bold : FontWeight.normal,
                                )),

                            const Divider(),

                            // Escalation Factors
                            Text('Priority: ${notice.priority ?? "None"}',
                                style: TextStyle(
                                    color: notice.priority == "Final/Levy/Lien" ? Colors.red : Colors.black
                                )),
                            Text('Notice Issue: ${notice.noticeIssue ?? "None"}'),
                            Text('Description: ${notice.description ?? "None"}'),

                            if (calls.isNotEmpty) ...[
                              const Divider(),
                              Text('Calls (${calls.length}):'),
                              ...calls.map((call) => Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Text('• ${call.date.toLocal().toString().split(' ')[0]} - ${call.outcome ?? "No outcome"} - Follow-up: ${call.followUpDate ?? "None"}'),
                              )),
                            ],

                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    // Print debug info to console
                                    NoticeLogic.debugNotice(notice, calls);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Debug info for ${notice.autoId} printed to console')),
                                    );
                                  },
                                  child: const Text('Debug Console'),
                                ),
                                const SizedBox(width: 8),
                                if (calculatedStatus != notice.status)
                                  ElevatedButton(
                                    onPressed: () async {
                                      // Update the notice status
                                      await FirebaseFirestore.instance
                                          .collection('notices')
                                          .doc(notice.id)
                                          .update({'status': calculatedStatus});

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Updated ${notice.autoId} status to $calculatedStatus')),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                    child: const Text('Fix Status'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}