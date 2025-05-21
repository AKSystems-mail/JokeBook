// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BitAdapter extends TypeAdapter<Bit> {
  @override
  final int typeId = 0;

  @override
  Bit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bit(
      id: fields[0] as String,
      title: fields[1] as String,
      body: fields[2] as String,
      userId: fields[3] as String,
      createdAt: fields[4] as Timestamp,
      updatedAt: fields[5] as Timestamp,
      order: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Bit obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(3)
      ..write(obj.userId)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
