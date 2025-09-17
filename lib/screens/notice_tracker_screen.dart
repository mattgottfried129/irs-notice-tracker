import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../models/notice.dart';
import 'notice_detail_screen.dart';

class NoticeTrackerScreen extends StatelessWidget {
  final String? filterStatus;

  const NoticeTrackerScreen({super.key, this.filterStatus});

  @override
  Widget build(BuildContext context) {
    List<Notice> notices = dummyNotices;
    if (filterStatus != null && filterStatus != "All") {
      if (filterStatus == "Missing POA") {
        notices = notices.where((n) => !n.poaOnFile).toList();
      } else {
        notices = notices.where((n) => n.status == filterStatus).toList();
      }
    }

    return ListView.builder(
      itemCount: notices.length,
      itemBuilder: (context, index) {
        final notice = notices[index];
        return ListTile(
          title: Text("Notice ${notice.noticeNumber}"),
          subtitle: Text(
              "Client: ${notice.clientId} | Status: ${notice.status}"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NoticeDetailScreen(notice: notice),
              ),
            );
          },
        );
      },
    );
  }
}
