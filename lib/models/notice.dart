import 'package:hive/hive.dart';
import 'call.dart';

part 'notice.g.dart';

@HiveType(typeId: 2)
class Notice extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String clientId;

  @HiveField(2)
  String noticeNumber;

  @HiveField(3)
  String period;

  @HiveField(4)
  DateTime dateReceived;

  @HiveField(5)
  DateTime dueDate;

  @HiveField(6)
  String status;

  @HiveField(7)
  String issue;

  @HiveField(8)
  bool poaOnFile;

  @HiveField(9)
  List<Call> calls;

  Notice({
    required this.id,
    required this.clientId,
    required this.noticeNumber,
    required this.period,
    required this.dateReceived,
    required this.dueDate,
    required this.status,
    required this.issue,
    this.calls = const [],
    this.poaOnFile = false, // ✅ default value
  });
}
