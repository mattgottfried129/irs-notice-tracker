import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/notice_logic.dart';
import 'call.dart';

part 'notice.g.dart';

@HiveType(typeId: 2)
class Notice extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String clientId;

  @HiveField(2)
  String noticeNumber;

  @HiveField(3)
  String status; // Stored status (may differ from derived)

  @HiveField(4)
  DateTime? dateReceived;

  @HiveField(5)
  String? formNumber;

  @HiveField(6)
  String? taxPeriod;

  @HiveField(7)
  bool needsPoa;

  @HiveField(8)
  String? description;

  @HiveField(9)
  DateTime? dateCompleted;

  @HiveField(10)
  String? representativeId;

  @HiveField(11)
  String? filingStatus;

  @HiveField(12)
  String? paymentPlan;

  @HiveField(13)
  double? amountOwed;

  @HiveField(14)
  double? amountPaid;

  @HiveField(15)
  DateTime? nextFollowUpDate;

  @HiveField(16)
  String? priority;

  @HiveField(17)
  List<String>? attachmentPaths;

  @HiveField(18)
  Map<String, dynamic>? customFields;

  @HiveField(19)
  String? autoId;

  @HiveField(20)
  String? noticeIssue;

  @HiveField(21)
  int? daysToRespond;

  @HiveField(22)
  String? notes;

  @HiveField(23)
  bool poaOnFile;

  @HiveField(24)
  DateTime? responseDeadline; // For follow-up dates from calls

  @HiveField(25)
  DateTime? computedDueDate; // Computed due date field

  Notice({
    required this.id,
    required this.clientId,
    required this.noticeNumber,
    required this.status,
    this.dateReceived,
    this.formNumber,
    this.taxPeriod,
    this.needsPoa = false,
    this.description,
    this.dateCompleted,
    this.representativeId,
    this.filingStatus,
    this.paymentPlan,
    this.amountOwed,
    this.amountPaid,
    this.nextFollowUpDate,
    this.priority,
    this.attachmentPaths,
    this.customFields,
    this.autoId,
    this.noticeIssue,
    this.daysToRespond,
    this.notes,
    this.poaOnFile = false,
    this.responseDeadline,
    this.computedDueDate,
    // Backward compatibility
    String? noticeForm,
    String? noticePeriod,
    DateTime? noticeDate,
  }) {
    if (noticeForm != null) formNumber = noticeForm;
    if (noticePeriod != null) taxPeriod = noticePeriod;
    if (noticeDate != null) dateReceived = noticeDate;
  }

  // 📹 Compatibility Getters
  String? get noticeForm => formNumber;
  String? get noticePeriod => taxPeriod;
  DateTime? get noticeDate => dateReceived;

  // 📹 Enhanced Due Date Logic with Follow-up Support
  DateTime? get dueDate {
    // Priority 1: Use computedDueDate if it exists (from follow-ups)
    if (computedDueDate != null) {
      return computedDueDate;
    }

    // Priority 2: Use responseDeadline if it exists (from follow-ups)
    if (responseDeadline != null) {
      return responseDeadline;
    }

    // Priority 3: Use nextFollowUpDate if it exists
    if (nextFollowUpDate != null) {
      return nextFollowUpDate;
    }

    // Priority 4: Calculate from original notice date + days to respond
    if (dateReceived != null && daysToRespond != null) {
      return dateReceived!.add(Duration(days: daysToRespond!));
    }

    return null;
  }

  // 📹 Firestore Auto-ID Generation
  static Future<String> generateAutoIdForClient(String clientId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('notices')
          .where('clientId', isEqualTo: clientId)
          .get();

      int highestNumber = 0;

      for (final doc in querySnapshot.docs) {
        final autoId = doc.data()['autoId'] as String?;
        if (autoId != null && autoId.startsWith('$clientId-N')) {
          final numberPart = autoId.substring('$clientId-N'.length);
          final number = int.tryParse(numberPart) ?? 0;
          if (number > highestNumber) highestNumber = number;
        }
      }

      final nextNumber = highestNumber + 1;
      final formattedNumber = nextNumber.toString().padLeft(4, '0');
      return '$clientId-N$formattedNumber';
    } catch (e) {
      print('Error generating auto ID: $e');
      return '$clientId-N0001';
    }
  }

  // 📹 Legacy Auto-ID
  static String generateAutoId() {
    final now = DateTime.now();
    return 'N${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';
  }

  // 📹 Firestore Mapper with New Fields
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'noticeNumber': noticeNumber,
      'status': status,
      'dateReceived': dateReceived?.millisecondsSinceEpoch,
      'formNumber': formNumber,
      'taxPeriod': taxPeriod,
      'needsPoa': needsPoa,
      'description': description,
      'dateCompleted': dateCompleted?.millisecondsSinceEpoch,
      'representativeId': representativeId,
      'filingStatus': filingStatus,
      'paymentPlan': paymentPlan,
      'amountOwed': amountOwed,
      'amountPaid': amountPaid,
      'nextFollowUpDate': nextFollowUpDate?.millisecondsSinceEpoch,
      'priority': priority,
      'attachmentPaths': attachmentPaths,
      'customFields': customFields,
      'autoId': autoId,
      'noticeIssue': noticeIssue,
      'daysToRespond': daysToRespond,
      'notes': notes,
      'poaOnFile': poaOnFile,
      // Add the new due date fields
      'responseDeadline': responseDeadline?.millisecondsSinceEpoch,
      'computedDueDate': computedDueDate?.millisecondsSinceEpoch,
    };
  }

  static Notice fromMap(Map<String, dynamic> map, String docId) {
    return Notice(
      id: map['id'] ?? docId,
      clientId: map['clientId'] ?? '',
      noticeNumber: map['noticeNumber'] ?? '',
      status: map['status'] ?? '',
      dateReceived: map['dateReceived'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateReceived'])
          : null,
      formNumber: map['formNumber'],
      taxPeriod: map['taxPeriod'],
      needsPoa: map['needsPoa'] ?? false,
      description: map['description'],
      dateCompleted: map['dateCompleted'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateCompleted'])
          : null,
      representativeId: map['representativeId'],
      filingStatus: map['filingStatus'],
      paymentPlan: map['paymentPlan'],
      amountOwed: map['amountOwed']?.toDouble(),
      amountPaid: map['amountPaid']?.toDouble(),
      nextFollowUpDate: map['nextFollowUpDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['nextFollowUpDate'])
          : null,
      priority: map['priority'],
      attachmentPaths: map['attachmentPaths']?.cast<String>(),
      customFields: map['customFields']?.cast<String, dynamic>(),
      autoId: map['autoId'],
      noticeIssue: map['noticeIssue'],
      daysToRespond: map['daysToRespond'],
      notes: map['notes'],
      poaOnFile: map['poaOnFile'] ?? false,
      // Add the new due date fields
      responseDeadline: map['responseDeadline'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['responseDeadline'])
          : null,
      computedDueDate: map['computedDueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['computedDueDate'])
          : null,
    )..id = docId;
  }
}

// 📹 Helpers for derived logic
extension NoticeHelpers on Notice {
  String derivedStatus(List<Call> calls) =>
      NoticeLogic.calculateStatus(this, calls);

  DateTime? responseDeadline(List<Call> calls) =>
      NoticeLogic.calculateResponseDeadline(this, calls);

  int? daysRemaining(List<Call> calls) =>
      NoticeLogic.calculateDaysRemaining(this, calls);

  bool isEscalated(List<Call> calls) =>
      NoticeLogic.isEscalated(this, calls);
}