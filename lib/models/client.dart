import 'package:hive/hive.dart';

part 'client.g.dart';

@HiveType(typeId: 0)
class Client extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String contact;

  @HiveField(3)
  String email;

  Client({
    required this.id,
    required this.name,
    required this.contact,
    required this.email,
  });
}
