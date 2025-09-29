import '../models/notice.dart';
import '../models/call.dart';

class NoticeLogic {
  /// Calculate Response Deadline
  static DateTime? calculateResponseDeadline(Notice notice, List<Call> calls) {
    // Check for earliest follow-up date from calls
    final followUps = calls
        .where((c) => c.noticeId == notice.id && c.followUpDate != null)
        .map((c) => c.followUpDate!)
        .toList();

    if (followUps.isNotEmpty) {
      followUps.sort();
      print('📅 Notice ${notice.autoId}: Using follow-up date ${followUps.first}');
      return followUps.first;
    }

    // Fallback: notice date + days to respond
    if (notice.dateReceived != null && notice.daysToRespond != null) {
      final deadline = notice.dateReceived!.add(Duration(days: notice.daysToRespond!));
      print('📅 Notice ${notice.autoId}: Calculated deadline from notice date ${notice.dateReceived} + ${notice.daysToRespond} days = $deadline');
      return deadline;
    }

    print('⚠️ Notice ${notice.autoId}: No deadline could be calculated (dateReceived: ${notice.dateReceived}, daysToRespond: ${notice.daysToRespond})');
    return null;
  }

  // Calculate Days Remaining
  static int? calculateDaysRemaining(Notice notice, List<Call> calls) {
    final deadline = calculateResponseDeadline(notice, calls);
    if (deadline == null) return null;

    final now = DateTime.now();
    final daysRemaining = deadline.difference(now).inDays;

    print('📊 Notice ${notice.autoId}: Days remaining calculation:');
    print('   Deadline: $deadline');
    print('   Now: $now');
    print('   Days remaining: $daysRemaining');

    return daysRemaining;
  }

  // Enhanced Escalation Logic with Debug Logging
  static bool isEscalated(Notice notice, List<Call> calls) {
    print('🔍 Checking escalation for Notice ${notice.autoId}:');

    // CRITICAL: Don't escalate closed notices
    if (notice.status.toLowerCase() == 'closed') {
      print('   ✅ NOT ESCALATED: Notice is already Closed');
      return false;
    }

    // Check if priority is set to Final/Levy/Lien
    final priority = notice.priority?.toLowerCase() ?? "";
    print('   Priority: "${notice.priority}" (normalized: "$priority")');
    if (priority == "final/levy/lien") {
      print('   ✅ ESCALATED: Priority is Final/Levy/Lien');
      return true;
    }

    // Check days remaining - escalate if 3 days or less (including overdue)
    final daysRemaining = calculateDaysRemaining(notice, calls);
    print('   Days remaining: $daysRemaining');
    if (daysRemaining != null && daysRemaining <= 3) {
      print('   ✅ ESCALATED: Days remaining ($daysRemaining) <= 3');
      return true;
    }

    // Check notice issue for escalation keywords
    final issue = notice.noticeIssue?.toLowerCase() ?? "";
    print('   Notice Issue: "${notice.noticeIssue}" (normalized: "$issue")');
    if (issue.contains("final") ||
        issue.contains("levy") ||
        issue.contains("lien") ||
        issue.contains("intent to levy") ||
        issue.contains("final notice")) {
      print('   ✅ ESCALATED: Notice issue contains escalation keywords');
      return true;
    }

    // Check notice description for escalation keywords
    final description = notice.description?.toLowerCase() ?? "";
    print('   Description: "${notice.description}" (normalized: "$description")');
    if (description.contains("final") ||
        description.contains("levy") ||
        description.contains("lien")) {
      print('   ✅ ESCALATED: Description contains escalation keywords');
      return true;
    }

    print('   ❌ NOT ESCALATED: No escalation criteria met');
    return false;
  }

  /// Status Calculation with Escalation Priority
  static String calculateStatus(Notice notice, List<Call> calls) {
    print('🎯 Calculating status for Notice ${notice.autoId}:');

    // CRITICAL: Preserve Closed status - don't override it
    if (notice.status.toLowerCase() == 'closed') {
      print('   Final Status: CLOSED (preserved - no override)');
      return "Closed";
    }

    // Check if resolved by calls
    final resolvedCalls = calls.where((c) => (c.outcome ?? "").toLowerCase() == "resolved").toList();
    if (resolvedCalls.isNotEmpty) {
      print('   Final Status: CLOSED (resolved calls found)');
      return "Closed";
    }

    // Check if escalated - this takes priority over other statuses
    if (isEscalated(notice, calls)) {
      print('   Final Status: ESCALATED');
      return "Escalated";
    }

    // Check specific waiting states
    final waitingOnClientCalls = calls.where((c) => (c.outcome ?? "").toLowerCase() == "waiting on client").toList();
    if (waitingOnClientCalls.isNotEmpty) {
      print('   Final Status: WAITING ON CLIENT');
      return "Waiting on Client";
    }

    final waitingOnIrsCalls = calls.where((c) => (c.outcome ?? "").toLowerCase() == "waiting on irs").toList();
    if (waitingOnIrsCalls.isNotEmpty) {
      print('   Final Status: AWAITING IRS RESPONSE');
      return "Awaiting IRS Response";
    }

    // Check for in-progress states
    final inProgressCalls = calls.where((c) {
      final outcome = (c.outcome ?? "").toLowerCase();
      return outcome == "awaiting irs response" ||
          outcome == "monitor account" ||
          outcome == "submit documentation" ||
          outcome == "follow-up call" ||
          outcome == "other (details in notes)";
    }).toList();

    if (inProgressCalls.isNotEmpty) {
      print('   Final Status: IN PROGRESS (specific outcomes found)');
      return "In Progress";
    }

    // If there are any calls at all, consider it in progress
    if (calls.isNotEmpty) {
      print('   Final Status: IN PROGRESS (has calls)');
      return "In Progress";
    }

    // Default status
    print('   Final Status: OPEN (default)');
    return "Open";
  }

  /// Helper method to get current date info for debugging
  static void debugCurrentDate() {
    final now = DateTime.now();
    print('🕐 Current date/time info:');
    print('   DateTime.now(): $now');
    print('   Date only: ${now.toLocal().toString().split(' ')[0]}');
    print('   Timezone: ${now.timeZoneName}');
  }

  /// Helper method to debug a specific notice
  static void debugNotice(Notice notice, List<Call> calls) {
    print('\n🔍 === DEBUG NOTICE ${notice.autoId} ===');
    debugCurrentDate();
    print('📋 Notice Details:');
    print('   ID: ${notice.id}');
    print('   Auto ID: ${notice.autoId}');
    print('   Client ID: ${notice.clientId}');
    print('   Notice Number: ${notice.noticeNumber}');
    print('   Current Status: ${notice.status}');
    print('   Priority: ${notice.priority}');
    print('   Date Received: ${notice.dateReceived}');
    print('   Days to Respond: ${notice.daysToRespond}');
    print('   Notice Issue: ${notice.noticeIssue}');
    print('   Description: ${notice.description}');

    final deadline = calculateResponseDeadline(notice, calls);
    final daysRemaining = calculateDaysRemaining(notice, calls);
    final escalated = isEscalated(notice, calls);
    final calculatedStatus = calculateStatus(notice, calls);

    print('📊 Calculated Values:');
    print('   Response Deadline: $deadline');
    print('   Days Remaining: $daysRemaining');
    print('   Should be Escalated: $escalated');
    print('   Calculated Status: $calculatedStatus');

    print('📞 Calls (${calls.length}):');
    for (var call in calls) {
      print('   - Date: ${call.date}, Outcome: ${call.outcome}, Follow-up: ${call.followUpDate}');
    }

    print('=== END DEBUG ===\n');
  }
}