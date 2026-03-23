// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_purchase_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SupplierPurchaseItemModelAdapter
    extends TypeAdapter<SupplierPurchaseItemModel> {
  @override
  final int typeId = 9;

  @override
  SupplierPurchaseItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SupplierPurchaseItemModel(
      productId: fields[0] as String,
      productName: fields[1] as String,
      quantity: fields[2] as double,
      unit: fields[3] as String,
      price: fields[4] as double,
      total: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SupplierPurchaseItemModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.unit)
      ..writeByte(4)
      ..write(obj.price)
      ..writeByte(5)
      ..write(obj.total);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierPurchaseItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SupplierPurchaseModelAdapter extends TypeAdapter<SupplierPurchaseModel> {
  @override
  final int typeId = 8;

  @override
  SupplierPurchaseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SupplierPurchaseModel(
      id: fields[0] as String,
      supplierId: fields[1] as String,
      supplierName: fields[2] as String,
      date: fields[3] as DateTime,
      items: (fields[4] as List).cast<SupplierPurchaseItemModel>(),
      totalAmount: fields[5] as double,
      amountPaid: fields[6] == null ? 0.0 : fields[6] as double,
      userId: fields[7] as String,
      pendingSync: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SupplierPurchaseModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.supplierId)
      ..writeByte(2)
      ..write(obj.supplierName)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.items)
      ..writeByte(5)
      ..write(obj.totalAmount)
      ..writeByte(6)
      ..write(obj.amountPaid)
      ..writeByte(7)
      ..write(obj.userId)
      ..writeByte(8)
      ..write(obj.pendingSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierPurchaseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
