// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionItemModelAdapter extends TypeAdapter<TransactionItemModel> {
  @override
  final int typeId = 2;

  @override
  TransactionItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionItemModel(
      productId: fields[0] as String,
      productName: fields[1] as String,
      price: fields[2] as double,
      quantity: fields[3] as int,
      total: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionItemModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.total);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 3;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      totalAmount: fields[2] as double,
      items: (fields[3] as List).cast<TransactionItemModel>(),
      userId: fields[4] as String,
      pendingSync: fields[5] as bool,
      customerId: fields[6] as String,
      customerName: fields[7] as String,
      amountPaid: fields[8] == null ? 0.0 : fields[8] as double,
      paymentMethod: fields[9] == null ? 'cash' : fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.totalAmount)
      ..writeByte(3)
      ..write(obj.items)
      ..writeByte(4)
      ..write(obj.userId)
      ..writeByte(5)
      ..write(obj.pendingSync)
      ..writeByte(6)
      ..write(obj.customerId)
      ..writeByte(7)
      ..write(obj.customerName)
      ..writeByte(8)
      ..write(obj.amountPaid)
      ..writeByte(9)
      ..write(obj.paymentMethod);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
