// GENERATED CODE - DO NOT MODIFY BY HAND
// This is a placeholder. Run `dart run build_runner build` to generate.

part of 'conversion_model.dart';

class ConversionRecordAdapter extends TypeAdapter<ConversionRecord> {
  @override
  final int typeId = 0;

  @override
  ConversionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConversionRecord(
      id: fields[0] as String,
      typeIndex: fields[1] as String,
      inputFileName: fields[2] as String,
      outputFilePath: fields[3] as String?,
      createdAt: fields[4] as DateTime,
      inputFileSizeBytes: fields[5] as int,
      outputFileSizeBytes: fields[6] as int?,
      isSuccess: fields[7] as bool,
      errorMessage: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ConversionRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.typeIndex)
      ..writeByte(2)
      ..write(obj.inputFileName)
      ..writeByte(3)
      ..write(obj.outputFilePath)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.inputFileSizeBytes)
      ..writeByte(6)
      ..write(obj.outputFileSizeBytes)
      ..writeByte(7)
      ..write(obj.isSuccess)
      ..writeByte(8)
      ..write(obj.errorMessage);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
