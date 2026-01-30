// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_action.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendanceActionAdapter extends TypeAdapter<AttendanceAction> {
  @override
  final int typeId = 2;

  @override
  AttendanceAction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttendanceAction(
      subjectId: fields[0] as String,
      date: fields[1] as DateTime,
      wasPresent: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AttendanceAction obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.subjectId)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.wasPresent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
