import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:irs_notice_tracker/screens/add_call_screen.dart';

import '../models/notice.dart';
import '../models/poa_record.dart';
import '../models/client.dart';
import 'notice_detail_screen.dart';
import 'notice_tracker_screen.dart';
import 'poa_import_screen.dart';
import 'add_call_screen.dart';
import 'print_dashboard_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<bool> _hasValidPOA(Notice notice, List<PoaRecord> poaRecords) async {
    if (notice.formNumber == null || notice.taxPeriod == null) return false;

    final noticePeriodInt = int.tryParse(notice.taxPeriod!);
    if (noticePeriodInt == null) return false;

    return poaRecords.any((p) {
      final start = int.tryParse(p.periodStart);
      final end = int.tryParse(p.periodEnd);
      if (start == null || end == null) return false;

      return p.clientId == notice.clientId &&
          p.form == notice.formNumber &&
          noticePeriodInt >= start &&
          noticePeriodInt <= end;
    });
  }

  Future<Client?> _getClientById(String clientId) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // First try to get by document ID
      final doc = await firestore.collection('clients').doc(clientId).get();
      if (doc.exists) {
        return Client.fromMap(doc.data()!, doc.id);
      }

      // If not found by doc ID, search by client ID field
      final querySnapshot = await firestore.collection('clients')
          .where('id', isEqualTo: clientId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return Client.fromMap(doc.data(), doc.id);
      }
    } catch (e) {
      print('Error loading client: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddCallScreen(
                noticeId: "",
                clientId: "",
              ),
            ),
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add_call),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('notices').snapshots(),
          builder: (context, noticeSnapshot) {
            if (noticeSnapshot.hasError) {
              return Center(child: Text('Error: ${noticeSnapshot.error}'));
            }

            if (noticeSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final notices = noticeSnapshot.data?.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Notice.fromMap(data, doc.id);
            }).toList() ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('poaRecords').snapshots(),
              builder: (context, poaSnapshot) {
                if (poaSnapshot.hasError) {
                  return Center(child: Text('Error: ${poaSnapshot.error}'));
                }

                final poaRecords = poaSnapshot.data?.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return PoaRecord.fromMap(data, doc.id);
                }).toList() ?? [];

                // Calculate counts
                final openCount = notices.where((n) => n.status == "Open").length;
                final inProgressCount = notices.where((n) => n.status == "In Progress").length;
                final waitingCount = notices.where((n) =>
                n.status == "Waiting on Client" || n.status == "Awaiting IRS Response"
                ).length;
                final escalatedCount = notices.where((n) => n.status == "Escalated").length;
                final closedCount = notices.where((n) => n.status == "Closed").length;

                // Calculate missing POA count
                int missingPoaCount = 0;
                for (final notice in notices) {
                  if (!_hasValidPOASync(notice, poaRecords)) {
                    missingPoaCount++;
                  }
                }

                // Sort notices by due date
                final sortedNotices = notices
                    .where((n) => n.status != "Closed")
                    .toList()
                  ..sort((a, b) {
                    final aDueDate = a.dueDate ?? DateTime.now().add(const Duration(days: 365));
                    final bDueDate = b.dueDate ?? DateTime.now().add(const Duration(days: 365));
                    return aDueDate.compareTo(bDueDate);
                  });

                final top10Notices = sortedNotices.take(10).toList();
                final escalatedNotices = notices.where((n) => n.status == "Escalated").toList();
                final missingPoaNotices = notices.where((n) => !_hasValidPOASync(n, poaRecords)).toList();

                return ListView(
                  children: [
                    // Status Cards Grid
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: MediaQuery.of(context).size.width < 600 ? 1.2 : 1.6,
                      children: [
                        _buildStatusCard(
                          context,
                          label: "Open",
                          count: openCount,
                          color: Colors.blue,
                          icon: Icons.mark_email_unread,
                          onTap: () => _goToFilteredNotices(context, "Open"),
                        ),
                        _buildStatusCard(
                          context,
                          label: "In Progress",
                          count: inProgressCount,
                          color: Colors.orange,
                          icon: Icons.pending_actions,
                          onTap: () => _goToFilteredNotices(context, "In Progress"),
                        ),
                        _buildStatusCard(
                          context,
                          label: "Waiting",
                          count: waitingCount,
                          color: Colors.purple,
                          icon: Icons.hourglass_empty,
                          onTap: () => _goToFilteredNotices(context, "Waiting"),
                        ),
                        _buildStatusCard(
                          context,
                          label: "Escalated",
                          count: escalatedCount,
                          color: Colors.red,
                          icon: Icons.priority_high,
                          onTap: () => _goToFilteredNotices(context, "Escalated"),
                        ),
                        _buildStatusCard(
                          context,
                          label: "Closed",
                          count: closedCount,
                          color: Colors.green,
                          icon: Icons.check_circle,
                          onTap: () => _goToFilteredNotices(context, "Closed"),
                        ),
                        _buildStatusCard(
                          context,
                          label: "Missing POA",
                          count: missingPoaCount,
                          color: Colors.teal,
                          icon: Icons.assignment_late,
                          onTap: () => _goToFilteredNotices(context, "MissingPOA"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Next Due Notices
                    _buildSectionHeader(
                      context,
                      "Next Due Notices",
                      onViewAll: () => _goToFilteredNotices(context, "All"),
                    ),
                    if (top10Notices.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("No notices found"),
                        ),
                      )
                    else
                      ...top10Notices.map(
                            (n) => _buildNoticeTile(context, n, poaRecords),
                      ),

                    const SizedBox(height: 24),

                    // Escalated Notices
                    _buildSectionHeader(
                      context,
                      "Escalated Notices",
                      onViewAll: () => _goToFilteredNotices(context, "Escalated"),
                    ),
                    if (escalatedNotices.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("No escalated notices"),
                        ),
                      )
                    else
                      ...escalatedNotices.map(
                            (n) => _buildNoticeTile(context, n, poaRecords),
                      ),

                    const SizedBox(height: 24),

                    // Missing POA Notices
                    _buildSectionHeader(
                      context,
                      "Missing POA",
                      onViewAll: () => _goToFilteredNotices(context, "MissingPOA"),
                    ),
                    if (missingPoaNotices.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("All notices have valid POA coverage"),
                        ),
                      )
                    else
                      ...missingPoaNotices.map(
                            (n) => _buildNoticeTile(context, n, poaRecords),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Synchronous version for filtering
  bool _hasValidPOASync(Notice notice, List<PoaRecord> poaRecords) {
    if (notice.formNumber == null || notice.taxPeriod == null) return false;

    final noticePeriodInt = int.tryParse(notice.taxPeriod!);
    if (noticePeriodInt == null) return false;

    return poaRecords.any((p) {
      final start = int.tryParse(p.periodStart);
      final end = int.tryParse(p.periodEnd);
      if (start == null || end == null) return false;

      return p.clientId == notice.clientId &&
          p.form == notice.formNumber &&
          noticePeriodInt >= start &&
          noticePeriodInt <= end;
    });
  }

  Widget _buildStatusCard(
      BuildContext context, {
        required String label,
        required int count,
        required Color color,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: color),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                "$count",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context,
      String title, {
        required VoidCallback onViewAll,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        TextButton(onPressed: onViewAll, child: const Text("View All")),
      ],
    );
  }

  Widget _buildNoticeTile(
      BuildContext context,
      Notice notice,
      List<PoaRecord> poaRecords,
      ) {
    final dueDate = notice.dueDate;
    final hasPOA = _hasValidPOASync(notice, poaRecords);

    return Card(
      child: ListTile(
        title: FutureBuilder<Client?>(
          future: _getClientById(notice.clientId),
          builder: (context, snapshot) {
            final client = snapshot.data;
            final clientName = client?.name ?? 'Loading...';
            return Text("${notice.autoId ?? notice.noticeNumber} - $clientName");
          },
        ),
        subtitle: Text(
          "Status: ${notice.status} | Due: ${dueDate != null ? dueDate.toLocal().toString().split(' ')[0] : 'N/A'}",
        ),
        trailing: hasPOA
            ? const Tooltip(
          message: 'Valid POA on file',
          child: Icon(Icons.verified_user, color: Colors.green),
        )
            : const Tooltip(
          message: 'Missing or invalid POA',
          child: Icon(Icons.warning_amber, color: Colors.red),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoticeDetailScreen(noticeId: notice.id),
            ),
          );
        },
      ),
    );
  }

  void _goToFilteredNotices(BuildContext context, String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilteredNoticeTrackerScreen(statusFilter: filter),
      ),
    );
  }
}

// New screen that shows filtered notices
class FilteredNoticeTrackerScreen extends StatelessWidget {
  final String statusFilter;

  const FilteredNoticeTrackerScreen({super.key, required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    String title = "All Notices";
    switch (statusFilter) {
      case "Open":
        title = "Open Notices";
        break;
      case "In Progress":
        title = "In Progress Notices";
        break;
      case "Waiting":
        title = "Waiting Notices";
        break;
      case "Escalated":
        title = "Escalated Notices";
        break;
      case "Closed":
        title = "Closed Notices";
        break;
      case "MissingPOA":
        title = "Missing POA Notices";
        break;
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: "Print Dashboard",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrintDashboardScreen(),
                  ),
                );
              },
            ),
          ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notices').snapshots(),
        builder: (context, noticeSnapshot) {
          if (noticeSnapshot.hasError) {
            return Center(child: Text('Error: ${noticeSnapshot.error}'));
          }

          if (noticeSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allNotices = noticeSnapshot.data?.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Notice.fromMap(data, doc.id);
          }).toList() ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('poaRecords').snapshots(),
            builder: (context, poaSnapshot) {
              final poaRecords = poaSnapshot.data?.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return PoaRecord.fromMap(data, doc.id);
              }).toList() ?? [];

              // Filter notices based on status
              List<Notice> filteredNotices;
              switch (statusFilter) {
                case "Open":
                  filteredNotices = allNotices.where((n) => n.status == "Open").toList();
                  break;
                case "In Progress":
                  filteredNotices = allNotices.where((n) => n.status == "In Progress").toList();
                  break;
                case "Waiting":
                  filteredNotices = allNotices.where((n) =>
                  n.status == "Waiting on Client" || n.status == "Awaiting IRS Response"
                  ).toList();
                  break;
                case "Escalated":
                  filteredNotices = allNotices.where((n) => n.status == "Escalated").toList();
                  break;
                case "Closed":
                  filteredNotices = allNotices.where((n) => n.status == "Closed").toList();
                  break;
                case "MissingPOA":
                  filteredNotices = allNotices.where((n) => !_hasValidPOASync(n, poaRecords)).toList();
                  break;
                default:
                  filteredNotices = allNotices;
              }

              if (filteredNotices.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text("No $title found"),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: filteredNotices.length,
                itemBuilder: (context, index) {
                  final notice = filteredNotices[index];
                  final dueDate = notice.dueDate;
                  final hasPOA = _hasValidPOASync(notice, poaRecords);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(notice.status),
                        child: Text(
                          notice.status[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(notice.autoId ?? "Unknown Notice"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (notice.noticeIssue != null)
                            Text(notice.noticeIssue!),
                          Text(
                            "Status: ${notice.status} | Due: ${dueDate != null ? dueDate.toLocal().toString().split(' ')[0] : 'N/A'}",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasPOA)
                            const Tooltip(
                              message: 'Valid POA on file',
                              child: Icon(Icons.verified_user, color: Colors.green),
                            )
                          else
                            const Tooltip(
                              message: 'Missing or invalid POA',
                              child: Icon(Icons.warning_amber, color: Colors.red),
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NoticeDetailScreen(noticeId: notice.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  bool _hasValidPOASync(Notice notice, List<PoaRecord> poaRecords) {
    if (notice.formNumber == null || notice.taxPeriod == null) return false;

    final noticePeriodInt = int.tryParse(notice.taxPeriod!);
    if (noticePeriodInt == null) return false;

    return poaRecords.any((p) {
      final start = int.tryParse(p.periodStart);
      final end = int.tryParse(p.periodEnd);
      if (start == null || end == null) return false;

      return p.clientId == notice.clientId &&
          p.form == notice.formNumber &&
          noticePeriodInt >= start &&
          noticePeriodInt <= end;
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'escalated':
        return Colors.red;
      case 'waiting on client':
      case 'awaiting irs response':
        return Colors.purple;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}