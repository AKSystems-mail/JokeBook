// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_list.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SetListAdapter extends TypeAdapter<SetList> {
  @override
  final int typeId = 1;

  @override
  SetList read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SetList(
      id: fields[0] as String,
      title: fields[1] as String,
      date: fields[2] as DateTime,
      bits: (fields[3] as List).cast<String>(),
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SetList obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.bits)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetListAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
