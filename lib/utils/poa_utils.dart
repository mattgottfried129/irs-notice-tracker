import 'package:hive/hive.dart';
import '../models/poa_record.dart';

/// Check if a POA exists for a client that covers the given form + period
bool hasValidPOA(String clientId, String form, String period) {
  final poaBox = Hive.box<POARecord>('poaRecords');

  for (var record in poaBox.values.where((r) => r.clientId == clientId)) {
    if (record.form != form) continue;

    // Simple string compare (works if format is YYYY or YYYYQn)
    if (period.compareTo(record.periodStart) >= 0 &&
        period.compareTo(record.periodEnd) <= 0) {
      return true;
    }
  }

  return false;
}
