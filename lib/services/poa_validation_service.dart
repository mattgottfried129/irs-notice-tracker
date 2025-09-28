import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poa_record.dart';
import '../models/notice.dart';
import '../models/client.dart';

class PoaValidationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Check if a notice has valid POA coverage
  /// For married couples, checks both taxpayer and spouse POAs
  static Future<bool> hasValidPOA(Notice notice) async {
    try {
      // Get client information
      final client = await _getClientById(notice.clientId);
      if (client == null) return false;

      // Get all POA records for this client
      final poaRecords = await getPOARecordsForClient(notice.clientId);

      // Check if notice has valid POA coverage
      return _checkPOACoverage(notice, poaRecords, client);
    } catch (e) {
      print('Error checking POA validity: $e');
      return false;
    }
  }

  /// Get all POA records for a client (both taxpayer and spouse)
  static Future<List<PoaRecord>> getPOARecordsForClient(String clientId) async {
    try {
      final snapshot = await _db
          .collection('poaRecords')
          .where('clientId', isEqualTo: clientId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => PoaRecord.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting POA records: $e');
      return [];
    }
  }

  /// Check POA coverage for a notice
  static bool _checkPOACoverage(Notice notice, List<PoaRecord> poaRecords, Client client) {
    // If no form or period specified, cannot validate
    if (notice.formNumber == null || notice.taxPeriod == null) {
      return false;
    }

    // For married filing clients, check if either taxpayer or spouse has valid POA
    if (client.isMarriedFiling) {
      // Check taxpayer POA
      bool taxpayerHasPOA = _hasValidPOAForType(
          poaRecords, 'Taxpayer', notice.formNumber!, notice.taxPeriod!
      );

      // Check spouse POA
      bool spouseHasPOA = _hasValidPOAForType(
          poaRecords, 'Spouse', notice.formNumber!, notice.taxPeriod!
      );

      // For married filing, either taxpayer or spouse POA can cover the notice
      return taxpayerHasPOA || spouseHasPOA;
    } else {
      // Single taxpayer - only check taxpayer POA
      return _hasValidPOAForType(
          poaRecords, 'Taxpayer', notice.formNumber!, notice.taxPeriod!
      );
    }
  }

  /// Check if specific taxpayer type has valid POA for form and period
  static bool _hasValidPOAForType(
      List<PoaRecord> poaRecords,
      String taxpayerType,
      String form,
      String period
      ) {
    return poaRecords.any((poa) =>
    poa.taxpayerType == taxpayerType &&
        poa.form == form &&
        poa.coversPeriod(period) &&
        poa.isActive
    );
  }

  /// Get POA status details for a notice (for UI display)
  static Future<POAStatus> getPOAStatusForNotice(Notice notice) async {
    try {
      final client = await _getClientById(notice.clientId);
      if (client == null) {
        return POAStatus(
          hasValidPOA: false,
          statusMessage: 'Client not found',
          taxpayerPOA: null,
          spousePOA: null,
        );
      }

      final poaRecords = await getPOARecordsForClient(notice.clientId);

      PoaRecord? taxpayerPOA;
      PoaRecord? spousePOA;

      if (notice.formNumber != null && notice.taxPeriod != null) {
        // Find matching POAs
        taxpayerPOA = poaRecords
            .where((poa) => poa.taxpayerType == 'Taxpayer' &&
            poa.form == notice.formNumber! &&
            poa.coversPeriod(notice.taxPeriod!))
            .firstOrNull;

        if (client.isMarriedFiling) {
          spousePOA = poaRecords
              .where((poa) => poa.taxpayerType == 'Spouse' &&
              poa.form == notice.formNumber! &&
              poa.coversPeriod(notice.taxPeriod!))
              .firstOrNull;
        }
      }

      final hasValid = taxpayerPOA != null || spousePOA != null;

      String statusMessage;
      if (!hasValid) {
        statusMessage = client.isMarriedFiling
            ? 'No valid POA for taxpayer or spouse'
            : 'No valid POA for taxpayer';
      } else if (taxpayerPOA != null && spousePOA != null) {
        statusMessage = 'Valid POA for both taxpayer and spouse';
      } else if (taxpayerPOA != null) {
        statusMessage = 'Valid POA for taxpayer';
      } else {
        statusMessage = 'Valid POA for spouse';
      }

      return POAStatus(
        hasValidPOA: hasValid,
        statusMessage: statusMessage,
        taxpayerPOA: taxpayerPOA,
        spousePOA: spousePOA,
      );
    } catch (e) {
      print('Error getting POA status: $e');
      return POAStatus(
        hasValidPOA: false,
        statusMessage: 'Error checking POA: $e',
        taxpayerPOA: null,
        spousePOA: null,
      );
    }
  }

  /// Get missing POA notices for dashboard
  static Future<List<Notice>> getNoticesWithMissingPOA() async {
    try {
      final noticesSnapshot = await _db.collection('notices').get();
      final notices = noticesSnapshot.docs
          .map((doc) => Notice.fromMap(doc.data(), doc.id))
          .toList();

      final missingPOANotices = <Notice>[];

      for (final notice in notices) {
        final hasValid = await hasValidPOA(notice);
        if (!hasValid) {
          missingPOANotices.add(notice);
        }
      }

      return missingPOANotices;
    } catch (e) {
      print('Error getting notices with missing POA: $e');
      return [];
    }
  }

  /// Create POA records for both spouses when creating married filing client
  static Future<void> createMarriedFilingPOAs({
    required String clientId,
    required String taxpayerName,
    required String spouseName,
    required String form,
    required String periodStart,
    required String periodEnd,
    bool electronicCopy = false,
    bool cafVerified = false,
    bool paperCopy = false,
  }) async {
    try {
      final batch = _db.batch();

      // Create taxpayer POA
      final taxpayerPOARef = _db.collection('poaRecords').doc();
      batch.set(taxpayerPOARef, {
        'clientId': clientId,
        'taxpayerType': 'Taxpayer',
        'taxpayerName': taxpayerName,
        'form': form,
        'periodStart': periodStart,
        'periodEnd': periodEnd,
        'dateReceived': DateTime.now().millisecondsSinceEpoch,
        'isActive': true,
        'electronicCopy': electronicCopy,
        'cafVerified': cafVerified,
        'paperCopy': paperCopy,
      });

      // Create spouse POA
      final spousePOARef = _db.collection('poaRecords').doc();
      batch.set(spousePOARef, {
        'clientId': clientId,
        'taxpayerType': 'Spouse',
        'taxpayerName': spouseName,
        'form': form,
        'periodStart': periodStart,
        'periodEnd': periodEnd,
        'dateReceived': DateTime.now().millisecondsSinceEpoch,
        'isActive': true,
        'electronicCopy': electronicCopy,
        'cafVerified': cafVerified,
        'paperCopy': paperCopy,
      });

      await batch.commit();
      print('✅ Created POA records for married filing couple: $clientId');
    } catch (e) {
      print('❌ Error creating married filing POAs: $e');
      rethrow;
    }
  }

  /// Helper method to get client by ID
  static Future<Client?> _getClientById(String clientId) async {
    try {
      final doc = await _db.collection('clients').doc(clientId).get();
      if (doc.exists) {
        return Client.fromMap(doc.data()!, doc.id);
      }

      // Fallback: search by client ID field
      final querySnapshot = await _db.collection('clients')
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
}

/// POA Status class for detailed POA information
class POAStatus {
  final bool hasValidPOA;
  final String statusMessage;
  final PoaRecord? taxpayerPOA;
  final PoaRecord? spousePOA;

  POAStatus({
    required this.hasValidPOA,
    required this.statusMessage,
    required this.taxpayerPOA,
    required this.spousePOA,
  });
}

/// Extension for null safety
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}