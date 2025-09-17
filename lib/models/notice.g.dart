// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notice.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NoticeAdapter extends TypeAdapter<Notice> {
  @override
  final int typeId = 2;

  @override
  Notice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Notice(
      id: fields[0] as int,
      clientId: fields[1] as String,
      noticeNumber: fields[2] as String,
      period: fields[3] as String,
      dateReceived: fields[4] as DateTime,
      dueDate: fields[5] as DateTime,
      status: fields[6] as String,
      issue: fields[7] as String,
      calls: (fields[9] as List).cast<Call>(),
      poaOnFile: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Notice obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clientId)
      ..writeByte(2)
      ..write(obj.noticeNumber)
      ..writeByte(3)
      ..write(obj.period)
      ..writeByte(4)
      ..write(obj.dateReceived)
      ..writeByte(5)
      ..write(obj.dueDate)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.issue)
      ..writeByte(8)
      ..write(obj.poaOnFile)
      ..writeByte(9)
      ..write(obj.calls);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoticeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
