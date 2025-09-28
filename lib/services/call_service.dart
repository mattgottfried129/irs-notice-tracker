import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call.dart';

class CallService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'calls';

  // Get all calls
  static Future<List<Call>> getCalls() async {
    final snapshot = await _db.collection(_collection).get();
    return snapshot.docs
        .map((doc) => Call.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Get calls by client ID
  static Future<List<Call>> getCallsByClientId(String clientId) async {
    final snapshot = await _db
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .get();
    return snapshot.docs
        .map((doc) => Call.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Get calls by notice ID
  static Future<List<Call>> getCallsByNoticeId(String noticeId) async {
    final snapshot = await _db
        .collection(_collection)
        .where('noticeId', isEqualTo: noticeId)
        .get();
    return snapshot.docs
        .map((doc) => Call.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Calculate billable amount for a call with proper per-notice logic
  static Future<double> calculateCallBillableAmount(Call call) async {
    if (!call.billable) return 0.0;

    final rate = call.hourlyRate ?? 250.0; // $250/hour rate
    final timeBasedAmount = (call.durationMinutes / 60.0) * rate;

    // Research calls: actual time, no minimum
    if (call.responseMethod.toLowerCase().contains('research')) {
      return _roundToNext5(timeBasedAmount);
    }

    // Non-research calls: get all calls for this notice
    final noticeCalls = await getCallsByNoticeId(call.noticeId);

    final nonResearchCalls = noticeCalls
        .where((c) =>
            c.billable && !c.responseMethod.toLowerCase().contains('research'))
        .toList();

    final totalNoticeMinutes =
        nonResearchCalls.fold<int>(0, (sum, c) => sum + c.durationMinutes);

    final totalNoticeHours = totalNoticeMinutes / 60.0;

    // If total time >= 1 hour, bill each call at actual time
    if (totalNoticeHours >= 1.0) {
      return _roundToNext5(timeBasedAmount);
    }

    // If total time < 1 hour, apply $250 minimum to first call only
    final sortedCalls = nonResearchCalls
      ..sort((a, b) => a.date.compareTo(b.date));
    if (sortedCalls.isNotEmpty && sortedCalls.first.id == call.id) {
      return 250.0; // First call gets the minimum
    }

    return 0.0; // Subsequent calls are covered by minimum
  }

  // Calculate client totals with proper billing logic
  static Future<Map<String, double>> calculateClientTotals(
      String clientId) async {
    final calls = await getCallsByClientId(clientId);

    double billedAmount = 0.0;
    double unbilledAmount = 0.0;

    // Group calls by notice ID
    final Map<String, List<Call>> callsByNotice = {};
    for (final call in calls) {
      callsByNotice.putIfAbsent(call.noticeId, () => []).add(call);
    }

    // Calculate billing for each notice
    for (final noticeCalls in callsByNotice.values) {
      for (final call in noticeCalls) {
        if (call.billable) {
          final amount = await calculateCallBillableAmount(call);
          if (call.billing == 'Billed') {
            billedAmount += amount;
          } else {
            unbilledAmount += amount;
          }
        }
      }
    }

    return {
      'billed': billedAmount,
      'unbilled': unbilledAmount,
      'total': billedAmount + unbilledAmount,
    };
  }

  // Calculate summary for all clients
  static Future<Map<String, Map<String, double>>>
      calculateAllClientTotals() async {
    final calls = await getCalls();
    final Map<String, Map<String, double>> clientTotals = {};

    // Group calls by client
    final Map<String, List<Call>> callsByClient = {};
    for (final call in calls) {
      callsByClient.putIfAbsent(call.clientId, () => []).add(call);
    }

    // Calculate totals for each client
    for (final entry in callsByClient.entries) {
      final clientId = entry.key;
      clientTotals[clientId] = await calculateClientTotals(clientId);
    }

    return clientTotals;
  }

  // Helper method to round up to nearest $5
  static double _roundToNext5(double amount) {
    return (amount / 5).ceil() * 5.0;
  }

  // Add call
  static Future<void> addCall(Call call) async {
    // Use the call's ID as the document ID to ensure consistency
    await _db.collection(_collection).doc(call.id).set(call.toMap());
  }

  // Update call
  static Future<void> updateCall(String callId, Call call) async {
    await _db.collection(_collection).doc(callId).update(call.toMap());
  }

  // Delete call
  static Future<void> deleteCall(String callId) async {
    await _db.collection(_collection).doc(callId).delete();
  }

  // Mark call as billed
  static Future<void> markCallAsBilled(String callId) async {
    await _db.collection(_collection).doc(callId).update({'billing': 'Billed'});
  }

  // Mark multiple calls as billed
  static Future<void> markCallsAsBilled(List<String> callIds) async {
    final batch = _db.batch();
    for (final callId in callIds) {
      final docRef = _db.collection(_collection).doc(callId);
      batch.update(docRef, {'billing': 'Billed'});
    }
    await batch.commit();
  }
}
