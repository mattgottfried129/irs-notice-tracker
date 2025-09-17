import 'package:hive/hive.dart';

part 'call.g.dart';

@HiveType(typeId: 3)
class Call extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  int noticeId;

  @HiveField(2)
  DateTime callDate;

  @HiveField(3)
  String irsLine;

  @HiveField(4)
  String agentName;

  @HiveField(5)
  String agentId;

  @HiveField(6)
  DateTime startTime;

  @HiveField(7)
  DateTime endTime;

  @HiveField(8)
  int holdMinutes; // 👈 separate hold time

  @HiveField(9)
  String notes;

  @HiveField(10)
  bool billed;

  Call({
    required this.id,
    required this.noticeId,
    required this.callDate,
    required this.irsLine,
    required this.agentName,
    required this.agentId,
    required this.startTime,
    required this.endTime,
    required this.holdMinutes,
    required this.notes,
    required this.billed,
  });

  Duration get rawDuration => endTime.difference(startTime);

  Duration get duration {
    final billedMinutes = rawDuration.inMinutes - holdMinutes;
    return Duration(minutes: billedMinutes > 0 ? billedMinutes : 0);
  }

  double get billedHours {
    final hours = duration.inMinutes / 60;
    return hours < 1 ? 1 : hours;
  }

  double get billAmount {
    if (!billed) return 0;
    final raw = billedHours * 250;
    return (raw / 5).round() * 5;
  }
}
