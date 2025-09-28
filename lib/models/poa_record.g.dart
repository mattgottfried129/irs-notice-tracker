// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poa_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PoaRecordAdapter extends TypeAdapter<PoaRecord> {
  @override
  final int typeId = 4;

  @override
  PoaRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PoaRecord(
      id: fields[0] as String?,
      clientId: fields[1] as String,
      form: fields[2] as String,
      periodStart: fields[3] as String,
      periodEnd: fields[4] as String,
      dateReceived: fields[5] as DateTime?,
      isActive: fields[6] as bool,
      taxpayerType: fields[7] as String,
      taxpayerName: fields[8] as String,
      electronicCopy: fields[9] as bool,
      cafVerified: fields[10] as bool,
      paperCopy: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PoaRecord obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clientId)
      ..writeByte(2)
      ..write(obj.form)
      ..writeByte(3)
      ..write(obj.periodStart)
      ..writeByte(4)
      ..write(obj.periodEnd)
      ..writeByte(5)
      ..write(obj.dateReceived)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.taxpayerType)
      ..writeByte(8)
      ..write(obj.taxpayerName)
      ..writeByte(9)
      ..write(obj.electronicCopy)
      ..writeByte(10)
      ..write(obj.cafVerified)
      ..writeByte(11)
      ..write(obj.paperCopy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PoaRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
