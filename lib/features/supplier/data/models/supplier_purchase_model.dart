import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../../domain/entities/supplier_purchase_entity.dart';

part 'supplier_purchase_model.g.dart';

@HiveType(typeId: 9)
class SupplierPurchaseItemModel {
  @HiveField(0)
  final String productId;

  @HiveField(1)
  final String productName;

  @HiveField(2)
  final double quantity;

  @HiveField(3)
  final String unit;

  @HiveField(4)
  final double price;

  @HiveField(5)
  final double total;

  SupplierPurchaseItemModel({
    this.productId = '',
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.total,
  });

  SupplierPurchaseItemEntity toEntity() => SupplierPurchaseItemEntity(
        productId: productId,
        productName: productName,
        quantity: quantity,
        unit: unit,
        price: price,
        total: total,
      );
}

@HiveType(typeId: 8)
class SupplierPurchaseModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String supplierId;

  @HiveField(2)
  final String supplierName;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final List<SupplierPurchaseItemModel> items;

  @HiveField(5)
  final double totalAmount;

  @HiveField(6, defaultValue: 0.0)
  final double amountPaid;

  @HiveField(7)
  final String userId;

  @HiveField(8)
  final bool pendingSync;

  SupplierPurchaseModel({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.date,
    required this.items,
    required this.totalAmount,
    this.amountPaid = 0.0,
    this.userId = '',
    this.pendingSync = false,
  });

  factory SupplierPurchaseModel.fromEntity(SupplierPurchaseEntity entity,
      {String userId = ''}) {
    return SupplierPurchaseModel(
      id: entity.id,
      supplierId: entity.supplierId,
      supplierName: entity.supplierName,
      date: entity.date,
      items: entity.items
          .map((i) => SupplierPurchaseItemModel(
                productId: i.productId,
                productName: i.productName,
                quantity: i.quantity,
                unit: i.unit,
                price: i.price,
                total: i.total,
              ))
          .toList(),
      totalAmount: entity.totalAmount,
      amountPaid: entity.amountPaid,
      userId: userId,
      pendingSync: entity.pendingSync,
    );
  }

  factory SupplierPurchaseModel.fromFirestore(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return SupplierPurchaseModel(
      id: map['id'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      supplierName: map['supplierName'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
      userId: map['userId'] as String? ?? '',
      pendingSync: false,
      items: rawItems
          .map((i) => SupplierPurchaseItemModel(
                productId: i['productId'] as String? ?? '',
                productName: i['productName'] as String? ?? '',
                quantity: (i['quantity'] as num?)?.toDouble() ?? 1.0,
                unit: i['unit'] as String? ?? 'Piece',
                price: (i['price'] as num?)?.toDouble() ?? 0.0,
                total: (i['total'] as num?)?.toDouble() ?? 0.0,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'date': Timestamp.fromDate(date),
        'totalAmount': totalAmount,
        'amountPaid': amountPaid,
        'userId': userId,
        'items': items
            .map((i) => {
                  'productId': i.productId,
                  'productName': i.productName,
                  'quantity': i.quantity,
                  'unit': i.unit,
                  'price': i.price,
                  'total': i.total,
                })
            .toList(),
      };

  SupplierPurchaseEntity toEntity() => SupplierPurchaseEntity(
        id: id,
        supplierId: supplierId,
        supplierName: supplierName,
        date: date,
        items: items.map((i) => i.toEntity()).toList(),
        totalAmount: totalAmount,
        amountPaid: amountPaid,
        userId: userId,
        pendingSync: pendingSync,
      );

  SupplierPurchaseModel copyWith({
    String? id,
    String? supplierId,
    String? supplierName,
    DateTime? date,
    List<SupplierPurchaseItemModel>? items,
    double? totalAmount,
    double? amountPaid,
    String? userId,
    bool? pendingSync,
  }) {
    return SupplierPurchaseModel(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      date: date ?? this.date,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      userId: userId ?? this.userId,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
