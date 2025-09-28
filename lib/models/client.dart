import 'package:hive/hive.dart';

part 'client.g.dart';

@HiveType(typeId: 0)
class Client extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String taxpayerName; // Primary taxpayer name

  @HiveField(2)
  String? email;

  @HiveField(3)
  String? phone;

  @HiveField(4)
  String? address;

  @HiveField(5)
  String? spouseName; // Spouse name (optional)

  @HiveField(6)
  bool isMarriedFiling; // Whether this is a married filing couple

  Client({
    String? id,
    String? clientId, // Backward compatibility
    required this.taxpayerName,
    this.spouseName,
    this.email,
    this.phone,
    this.address,
    this.isMarriedFiling = false,
    // Backward compatibility with old 'name' field
    String? name,
  }) : id = id ?? clientId ?? DateTime.now().millisecondsSinceEpoch.toString() {
    // Handle backward compatibility - if old 'name' is provided, use it as taxpayer name
    if (name != null && taxpayerName.isEmpty) {
      taxpayerName = name;
    }
  }

  // Backward compatibility getters
  String get clientId => id;
  String get name => displayName; // For backward compatibility with existing code

  // Display name for client list: "Taxpayer & Spouse"
  String get displayName {
    if (isMarriedFiling && spouseName != null && spouseName!.isNotEmpty) {
      return '$taxpayerName & $spouseName';
    }
    return taxpayerName;
  }

  // Full display with ID: "ClientID - Taxpayer & Spouse"
  String get fullDisplayName {
    return '$id - $displayName';
  }

  // Firestore toMap method
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taxpayerName': taxpayerName,
      'spouseName': spouseName,
      'email': email,
      'phone': phone,
      'address': address,
      'isMarriedFiling': isMarriedFiling,
      // Keep backward compatibility field for existing code
      'name': displayName,
    };
  }

  // Firestore fromMap method
  static Client fromMap(Map<String, dynamic> map, String docId) {
    // Handle backward compatibility for existing clients
    String taxpayerNameValue = '';
    String? spouseNameValue;
    bool isMarriedFilingValue = false;

    if (map.containsKey('taxpayerName')) {
      // New format
      taxpayerNameValue = map['taxpayerName'] ?? '';
      spouseNameValue = map['spouseName'];
      isMarriedFilingValue = map['isMarriedFiling'] ?? false;
    } else if (map.containsKey('name')) {
      // Old format - migrate to new format
      final oldName = map['name'] ?? '';

      // Check if old name contains '&' indicating married couple
      if (oldName.contains(' & ')) {
        final parts = oldName.split(' & ');
        taxpayerNameValue = parts[0].trim();
        spouseNameValue = parts.length > 1 ? parts[1].trim() : null;
        isMarriedFilingValue = spouseNameValue != null && spouseNameValue.isNotEmpty;
      } else {
        taxpayerNameValue = oldName;
        spouseNameValue = null;
        isMarriedFilingValue = false;
      }
    }

    return Client(
      id: map['id'] ?? docId,
      taxpayerName: taxpayerNameValue,
      spouseName: spouseNameValue,
      email: map['email'],
      phone: map['phone'],
      address: map['address'],
      isMarriedFiling: isMarriedFilingValue,
    );
  }
}