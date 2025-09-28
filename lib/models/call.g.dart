// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CallAdapter extends TypeAdapter<Call> {
  @override
  final int typeId = 3;

  @override
  Call read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Call(
      id: fields[0] as String?,
      noticeId: fields[1] as String,
      clientId: fields[2] as String,
      date: fields[3] as DateTime,
      responseMethod: fields[4] as String,
      irsLine: fields[5] as String,
      agentId: fields[6] as String?,
      issues: fields[7] as String?,
      notes: fields[8] as String?,
      outcome: fields[9] as String?,
      durationMinutes: fields[10] as int,
      billing: fields[11] as String,
      billable: fields[12] as bool,
      hourlyRate: fields[13] as double?,
      description: fields[14] as String?,
      minimumFee: fields[15] as double?,
      followUpDate: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Call obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.noticeId)
      ..writeByte(2)
      ..write(obj.clientId)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.responseMethod)
      ..writeByte(5)
      ..write(obj.irsLine)
      ..writeByte(6)
      ..write(obj.agentId)
      ..writeByte(7)
      ..write(obj.issues)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.outcome)
      ..writeByte(10)
      ..write(obj.durationMinutes)
      ..writeByte(11)
      ..write(obj.billing)
      ..writeByte(12)
      ..write(obj.billable)
      ..writeByte(13)
      ..write(obj.hourlyRate)
      ..writeByte(14)
      ..write(obj.description)
      ..writeByte(15)
      ..write(obj.minimumFee)
      ..writeByte(16)
      ..write(obj.followUpDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CallAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
