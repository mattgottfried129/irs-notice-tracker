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
      id: fields[0] as String,
      clientId: fields[1] as String,
      noticeNumber: fields[2] as String,
      status: fields[3] as String,
      dateReceived: fields[4] as DateTime?,
      formNumber: fields[5] as String?,
      taxPeriod: fields[6] as String?,
      needsPoa: fields[7] as bool,
      description: fields[8] as String?,
      dateCompleted: fields[9] as DateTime?,
      representativeId: fields[10] as String?,
      filingStatus: fields[11] as String?,
      paymentPlan: fields[12] as String?,
      amountOwed: fields[13] as double?,
      amountPaid: fields[14] as double?,
      nextFollowUpDate: fields[15] as DateTime?,
      priority: fields[16] as String?,
      attachmentPaths: (fields[17] as List?)?.cast<String>(),
      customFields: (fields[18] as Map?)?.cast<String, dynamic>(),
      autoId: fields[19] as String?,
      noticeIssue: fields[20] as String?,
      daysToRespond: fields[21] as int?,
      notes: fields[22] as String?,
      poaOnFile: fields[23] as bool,
      responseDeadline: fields[24] as DateTime?,
      computedDueDate: fields[25] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Notice obj) {
    writer
      ..writeByte(26)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.clientId)
      ..writeByte(2)
      ..write(obj.noticeNumber)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.dateReceived)
      ..writeByte(5)
      ..write(obj.formNumber)
      ..writeByte(6)
      ..write(obj.taxPeriod)
      ..writeByte(7)
      ..write(obj.needsPoa)
      ..writeByte(8)
      ..write(obj.description)
      ..writeByte(9)
      ..write(obj.dateCompleted)
      ..writeByte(10)
      ..write(obj.representativeId)
      ..writeByte(11)
      ..write(obj.filingStatus)
      ..writeByte(12)
      ..write(obj.paymentPlan)
      ..writeByte(13)
      ..write(obj.amountOwed)
      ..writeByte(14)
      ..write(obj.amountPaid)
      ..writeByte(15)
      ..write(obj.nextFollowUpDate)
      ..writeByte(16)
      ..write(obj.priority)
      ..writeByte(17)
      ..write(obj.attachmentPaths)
      ..writeByte(18)
      ..write(obj.customFields)
      ..writeByte(19)
      ..write(obj.autoId)
      ..writeByte(20)
      ..write(obj.noticeIssue)
      ..writeByte(21)
      ..write(obj.daysToRespond)
      ..writeByte(22)
      ..write(obj.notes)
      ..writeByte(23)
      ..write(obj.poaOnFile)
      ..writeByte(24)
      ..write(obj.responseDeadline)
      ..writeByte(25)
      ..write(obj.computedDueDate);
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
