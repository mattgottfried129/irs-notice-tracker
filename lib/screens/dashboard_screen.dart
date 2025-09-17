import 'package:flutter/material.dart';
import '../models/notice.dart';
import '../data/dummy_data.dart';
import 'notice_tracker_screen.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(String) onFilterSelect;

  const DashboardScreen({super.key, required this.onFilterSelect});

  List<Notice> _getTopNotices() {
    final open = dummyNotices.where((n) =>
    n.status == "Open" ||
        n.status == "In Progress" ||
        n.status == "Waiting on Client" ||
        n.status == "Escalated");
    return open.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final notices = dummyNotices;

    final openCount = notices.where((n) => n.status == "Open").length;
    final inProgressCount = notices.where((n) => n.status == "In Progress").length;
    final waitingCount = notices.where((n) => n.status == "Waiting on Client").length;
    final escalatedCount = notices.where((n) => n.status == "Escalated").length;
    final closedCount = notices.where((n) => n.status == "Closed").length;
    final missingPoaCount = notices.where((n) => !n.poaOnFile).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatusCard(
              context,
              label: "Open",
              count: openCount,
              color: Colors.blue,
              icon: Icons.mark_email_unread,
              onTap: () => onFilterSelect("Open"),
            ),
            _buildStatusCard(
              context,
              label: "In Progress",
              count: inProgressCount,
              color: Colors.orange,
              icon: Icons.work_history,
              onTap: () => onFilterSelect("In Progress"),
            ),
            _buildStatusCard(
              context,
              label: "Waiting on Client",
              count: waitingCount,
              color: Colors.purple,
              icon: Icons.hourglass_bottom,
              onTap: () => onFilterSelect("Waiting on Client"),
            ),
            _buildStatusCard(
              context,
              label: "Escalated",
              count: escalatedCount,
              color: Colors.red,
              icon: Icons.warning,
              onTap: () => onFilterSelect("Escalated"),
            ),
            _buildStatusCard(
              context,
              label: "Closed",
              count: closedCount,
              color: Colors.green,
              icon: Icons.check_circle,
              onTap: () => onFilterSelect("Closed"),
            ),
            _buildStatusCard(
              context,
              label: "Missing POA",
              count: missingPoaCount,
              color: Colors.grey,
              icon: Icons.assignment_late,
              onTap: () => onFilterSelect("Missing POA"),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          "Top 10 Notices Due Soon",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._getTopNotices().map((n) => Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.description, color: Colors.blue),
            title: Text("Notice ${n.noticeNumber}"),
            subtitle:
            Text("Client: ${n.clientId} | Status: ${n.status}"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      NoticeTrackerScreen(filterStatus: n.status),
                ),
              );
            },
          ),
        )),
      ],
    );
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
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
