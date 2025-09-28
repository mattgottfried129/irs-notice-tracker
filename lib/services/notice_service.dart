import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notice.dart';
import '../models/call.dart';
import 'notice_logic.dart';

class NoticeService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'notices';

  // ➕ Add notice
  static Future<void> addNotice(Notice notice) async {
    await _db.collection(_collection).doc(notice.id).set(notice.toMap());
  }

  // 🔥 Get all notices (raw)
  static Future<List<Notice>> getNotices() async {
    final snapshot = await _db.collection(_collection).get();
    return snapshot.docs
        .map((doc) => Notice.fromMap(doc.data(), doc.id))
        .toList();
  }

  // 📡 Stream notices with real-time status updates
  static Stream<List<Notice>> getNoticesStream() {
    return _db.collection(_collection).snapshots().asyncMap((snapshot) async {
      final notices = snapshot.docs
          .map((doc) => Notice.fromMap(doc.data(), doc.id))
          .toList();

      // Update statuses for all notices
      for (final notice in notices) {
        await _updateNoticeStatus(notice);
      }

      return notices;
    });
  }

  // 🔍 Get single notice (raw)
  static Future<Notice?> getNoticeById(String noticeId) async {
    try {
      final doc = await _db.collection(_collection).doc(noticeId).get();
      if (doc.exists) {
        final notice = Notice.fromMap(doc.data()!, doc.id);
        await _updateNoticeStatus(notice);
        return notice;
      }
    } catch (e) {
      print('Error getting notice: $e');
    }
    return null;
  }

  // ✏️ Update notice
  static Future<void> updateNotice(String noticeId, Notice notice) async {
    try {
      await _db.collection(_collection).doc(noticeId).update(notice.toMap());
      // Update status after saving
      await _updateNoticeStatus(notice);
    } catch (e) {
      print('Error updating notice: $e');
      rethrow;
    }
  }

  // ❌ Delete notice
  static Future<void> deleteNotice(String noticeId) async {
    try {
      await _db.collection(_collection).doc(noticeId).delete();
    } catch (e) {
      print('Error deleting notice: $e');
      rethrow;
    }
  }

  // 🔥 Get notices by client ID (raw)
  static Future<List<Notice>> getNoticesByClientId(String clientId) async {
    final snapshot = await _db
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .get();

    final notices = snapshot.docs
        .map((doc) => Notice.fromMap(doc.data(), doc.id))
        .toList();

    // Update statuses for client notices
    for (final notice in notices) {
      await _updateNoticeStatus(notice);
    }

    return notices;
  }

  // 🔹 Private method to update notice status and derived fields
  static Future<void> _updateNoticeStatus(Notice notice) async {
    try {
      // Get all calls for this notice
      final callsSnapshot = await _db
          .collection('calls')
          .where('noticeId', isEqualTo: notice.id)
          .get();

      final calls = callsSnapshot.docs
          .map((d) => Call.fromMap(d.data(), d.id))
          .toList();

      // Calculate derived fields using enhanced logic
      final derivedStatus = NoticeLogic.calculateStatus(notice, calls);
      final daysRemaining = NoticeLogic.calculateDaysRemaining(notice, calls);
      final escalated = NoticeLogic.isEscalated(notice, calls);
      final responseDeadline = NoticeLogic.calculateResponseDeadline(notice, calls);

      // Update the notice object
      notice.status = derivedStatus;
      notice.customFields ??= {};
      notice.customFields!['daysRemaining'] = daysRemaining;
      notice.customFields!['escalated'] = escalated;
      notice.customFields!['responseDeadline'] = responseDeadline?.millisecondsSinceEpoch;

      // Persist derived fields to Firestore
      final updateData = {
        'status': derivedStatus,
        'daysRemaining': daysRemaining,
        'escalated': escalated,
      };

      if (responseDeadline != null) {
        updateData['responseDeadline'] = responseDeadline.millisecondsSinceEpoch;
      }

      await _db.collection(_collection).doc(notice.id).update(updateData);

      print('✅ Updated notice ${notice.autoId ?? notice.id} status to: $derivedStatus (escalated: $escalated, days remaining: $daysRemaining)');
    } catch (e) {
      print('❌ Error updating notice status for ${notice.id}: $e');
    }
  }

  // 🔹 Get notices with enhanced filtering
  static Future<List<Notice>> getNoticesWithFilter(String filter) async {
    final notices = await getNotices();

    switch (filter.toLowerCase()) {
      case 'escalated':
        return notices.where((n) => n.status == 'Escalated').toList();
      case 'open':
        return notices.where((n) => n.status == 'Open').toList();
      case 'in progress':
        return notices.where((n) => n.status == 'In Progress').toList();
      case 'waiting on client':
        return notices.where((n) => n.status == 'Waiting on Client').toList();
      case 'awaiting irs response':
        return notices.where((n) => n.status == 'Awaiting IRS Response').toList();
      case 'closed':
        return notices.where((n) => n.status == 'Closed').toList();
      case 'overdue':
        return notices.where((n) {
          final daysRemaining = n.customFields?['daysRemaining'] as int?;
          return daysRemaining != null && daysRemaining < 0;
        }).toList();
      case 'due_soon':
        return notices.where((n) {
          final daysRemaining = n.customFields?['daysRemaining'] as int?;
          return daysRemaining != null && daysRemaining >= 0 && daysRemaining <= 3;
        }).toList();
      default:
        return notices;
    }
  }

  // 🔹 Force status recalculation for all notices (maintenance function)
  static Future<void> recalculateAllNoticeStatuses() async {
    print('🔄 Starting status recalculation for all notices...');
    try {
      final snapshot = await _db.collection(_collection).get();
      final notices = snapshot.docs
          .map((doc) => Notice.fromMap(doc.data(), doc.id))
          .toList();

      int updated = 0;
      for (final notice in notices) {
        await _updateNoticeStatus(notice);
        updated++;
        if (updated % 10 == 0) {
          print('📊 Updated $updated/${notices.length} notices...');
        }
      }

      print('✅ Completed status recalculation for $updated notices');
    } catch (e) {
      print('❌ Error during status recalculation: $e');
      rethrow;
    }
  }

  // 🔹 Get escalated notices specifically
  static Future<List<Notice>> getEscalatedNotices() async {
    return await getNoticesWithFilter('escalated');
  }

  // 🔹 Get overdue notices specifically
  static Future<List<Notice>> getOverdueNotices() async {
    return await getNoticesWithFilter('overdue');
  }
}