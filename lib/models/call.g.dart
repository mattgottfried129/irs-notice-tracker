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
      id: fields[0] as int,
      noticeId: fields[1] as int,
      callDate: fields[2] as DateTime,
      irsLine: fields[3] as String,
      agentName: fields[4] as String,
      agentId: fields[5] as String,
      startTime: fields[6] as DateTime,
      endTime: fields[7] as DateTime,
      holdMinutes: fields[8] as int,
      notes: fields[9] as String,
      billed: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Call obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.noticeId)
      ..writeByte(2)
      ..write(obj.callDate)
      ..writeByte(3)
      ..write(obj.irsLine)
      ..writeByte(4)
      ..write(obj.agentName)
      ..writeByte(5)
      ..write(obj.agentId)
      ..writeByte(6)
      ..write(obj.startTime)
      ..writeByte(7)
      ..write(obj.endTime)
      ..writeByte(8)
      ..write(obj.holdMinutes)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.billed);
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
