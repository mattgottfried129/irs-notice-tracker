import 'package:hive/hive.dart';

part 'poa_record.g.dart';

@HiveType(typeId: 4)
class PoaRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String clientId;

  @HiveField(2)
  String form;

  @HiveField(3)
  String periodStart;

  @HiveField(4)
  String periodEnd;

  @HiveField(5)
  DateTime? dateReceived;

  @HiveField(6)
  bool isActive;

  // New fields for married couples support
  @HiveField(7)
  String taxpayerType; // 'Taxpayer' or 'Spouse'

  @HiveField(8)
  String taxpayerName; // Individual name (either taxpayer or spouse)

  @HiveField(9)
  bool electronicCopy;

  @HiveField(10)
  bool cafVerified;

  @HiveField(11)
  bool paperCopy;

  PoaRecord({
    String? id,
    required this.clientId,
    required this.form,
    required this.periodStart,
    required this.periodEnd,
    this.dateReceived,
    this.isActive = true,
    this.taxpayerType = 'Taxpayer', // Default to Taxpayer for backward compatibility
    this.taxpayerName = '', // Will be populated from client data
    this.electronicCopy = false,
    this.cafVerified = false,
    this.paperCopy = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  // Display name: "ClientID - Taxpayer" or "ClientID - Spouse"
  String get displayName {
    return '$clientId - $taxpayerType';
  }

  // Full display with name: "ClientID - Taxpayer (John Smith)"
  String get fullDisplayName {
    if (taxpayerName.isNotEmpty) {
      return '$clientId - $taxpayerType ($taxpayerName)';
    }
    return '$clientId - $taxpayerType';
  }

  // Firestore toMap method
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'taxpayerType': taxpayerType,
      'taxpayerName': taxpayerName,
      'form': form,
      'periodStart': periodStart,
      'periodEnd': periodEnd,
      'dateReceived': dateReceived?.millisecondsSinceEpoch,
      'isActive': isActive,
      'electronicCopy': electronicCopy,
      'cafVerified': cafVerified,
      'paperCopy': paperCopy,
      // Backward compatibility
      'clientName': taxpayerName,
    };
  }

  // Firestore fromMap method with backward compatibility
  static PoaRecord fromMap(Map<String, dynamic> map, String docId) {
    return PoaRecord(
      id: map['id'] ?? docId,
      clientId: map['clientId'] ?? '',
      form: map['form'] ?? '',
      periodStart: map['periodStart'] ?? '',
      periodEnd: map['periodEnd'] ?? '',
      dateReceived: map['dateReceived'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateReceived'])
          : null,
      isActive: map['isActive'] ?? true,
      taxpayerType: map['taxpayerType'] ?? 'Taxpayer', // Default for old records
      taxpayerName: map['taxpayerName'] ?? map['clientName'] ?? '', // Backward compatibility
      electronicCopy: map['electronicCopy'] ?? false,
      cafVerified: map['cafVerified'] ?? false,
      paperCopy: map['paperCopy'] ?? false,
    );
  }

  // Helper method to check if POA covers a specific period
  bool coversPeriod(String targetPeriod) {
    final targetInt = int.tryParse(targetPeriod);
    final startInt = int.tryParse(periodStart);
    final endInt = int.tryParse(periodEnd);

    if (targetInt != null && startInt != null && endInt != null) {
      return targetInt >= startInt && targetInt <= endInt;
    }

    return periodStart == targetPeriod ||
        (periodStart.compareTo(targetPeriod) <= 0 &&
            periodEnd.compareTo(targetPeriod) >= 0);
  }
}