import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
part 'call.g.dart';

@HiveType(typeId: 3)
class Call extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String noticeId; // e.g. "TEST1234 - N0001"

  @HiveField(2)
  String clientId; // Link to client for billing

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  String responseMethod;

  @HiveField(5)
  String irsLine;

  @HiveField(6)
  String? agentId;

  @HiveField(7)
  String? issues;

  @HiveField(8)
  String? notes;

  @HiveField(9)
  String? outcome;

  @HiveField(10)
  int durationMinutes; // Duration in minutes

  @HiveField(11)
  String billing; // "Billed" / "Unbilled"

  @HiveField(12)
  bool billable; // Whether this call should be billed

  @HiveField(13)
  double? hourlyRate; // Custom rate for this call

  @HiveField(14)
  String? description; // Brief description for billing

  @HiveField(15)
  double? minimumFee; // Custom minimum fee for this call

  @HiveField(16)  // Fixed: Changed from 15 to 16
  DateTime? followUpDate;

  Call({
    String? id,
    required this.noticeId,
    required this.clientId,
    required this.date,
    required this.responseMethod,
    required this.irsLine,
    this.agentId,
    this.issues,
    this.notes,
    this.outcome,
    this.durationMinutes = 0,
    this.billing = "Unbilled",
    this.billable = true,
    this.hourlyRate,
    this.description,
    this.minimumFee,
    this.followUpDate,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  // Calculate billable amount with per-notice minimum fee logic
  double calculateBillableAmount(List<Call> allNoticeCalls) {
    if (!billable) return 0.0;

    final rate = hourlyRate ?? 250.0; // $250/hour rate
    final timeBasedAmount = (durationMinutes / 60.0) * rate;

    // Research calls: actual time, no minimum
    if (responseMethod.toLowerCase().contains('research')) {
      return _roundToNext5(timeBasedAmount);
    }

    // Non-research calls: 1-hour minimum per notice
    final nonResearchCalls = allNoticeCalls
        .where((c) => c.noticeId == noticeId &&
        c.billable &&
        !c.responseMethod.toLowerCase().contains('research'))
        .toList();

    final totalNoticeMinutes = nonResearchCalls
        .fold<int>(0, (sum, call) => sum + call.durationMinutes);

    final totalNoticeHours = totalNoticeMinutes / 60.0;

    // If total time >= 1 hour, bill each call at actual time
    if (totalNoticeHours >= 1.0) {
      return _roundToNext5(timeBasedAmount);
    }

    // If total time < 1 hour, apply $250 minimum to first call only
    final sortedCalls = nonResearchCalls..sort((a, b) => a.date.compareTo(b.date));
    if (sortedCalls.isNotEmpty && sortedCalls.first.id == id) {
      return 250.0; // First call gets the minimum
    }

    return 0.0; // Subsequent calls are covered by minimum
  }

  // Helper method to round up to nearest $5
  double _roundToNext5(double amount) {
    return (amount / 5).ceil() * 5.0;
  }

  // Backward compatibility getter
  double get billableAmount => calculateBillableAmount([]);

  // Add toMap method for Firestore
  // Replace your Call.toMap method in call.dart with this:

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'noticeId': noticeId,
      'clientId': clientId,
      'date': date.millisecondsSinceEpoch, // Always save as milliseconds
      'responseMethod': responseMethod,
      'irsLine': irsLine,
      'agentId': agentId,
      'issues': issues,
      'notes': notes,
      'outcome': outcome,
      'durationMinutes': durationMinutes,
      'billing': billing,
      'billable': billable,
      'hourlyRate': hourlyRate,
      'description': description,
      'minimumFee': minimumFee,
      // Note: followUpDate and responseDeadline are handled separately in the save method
    };
  }

  // Add fromMap method for Firestore
  static Call fromMap(Map<String, dynamic> map, String docId) {
    // Helper function to convert various date formats to DateTime
    DateTime? convertToDateTime(dynamic dateValue, String fieldName) {
      if (dateValue == null) return null;

      try {
        if (dateValue.runtimeType.toString() == 'Timestamp') {
          // Firestore Timestamp - convert using dynamic call
          return (dateValue as dynamic).toDate() as DateTime;
        } else if (dateValue is int) {
          // Milliseconds since epoch
          return DateTime.fromMillisecondsSinceEpoch(dateValue);
        } else if (dateValue is String) {
          // ISO string
          return DateTime.parse(dateValue);
        } else {
          print('❌ Unknown date type for $fieldName: ${dateValue.runtimeType}');
          return DateTime.now(); // fallback
        }
      } catch (e) {
        print('❌ Error converting $fieldName: $e');
        return DateTime.now(); // fallback
      }
    }

    return Call(
      id: map['id'] ?? docId,
      noticeId: map['noticeId'] ?? '',
      clientId: map['clientId'] ?? '',
      date: convertToDateTime(map['date'], 'date') ?? DateTime.now(),
      responseMethod: map['responseMethod'] ?? '',
      irsLine: map['irsLine'] ?? '',
      agentId: map['agentId'],
      issues: map['issues'],
      notes: map['notes'],
      outcome: map['outcome'],
      durationMinutes: map['durationMinutes'] ?? 0,
      billing: map['billing'] ?? 'Unbilled',
      billable: map['billable'] ?? true,
      hourlyRate: map['hourlyRate']?.toDouble(),
      description: map['description'],
      minimumFee: map['minimumFee']?.toDouble(),
    );
  }

  // Backward compatibility - keep old field name
  int? get callDuration => durationMinutes;
}