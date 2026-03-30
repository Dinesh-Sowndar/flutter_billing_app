class SupplierPurchaseItemEntity {
  final String productId; // '' if free-text
  final String productName;
  final double quantity;
  final String unit; // 'Piece', 'KG', 'Litre', 'Box', 'Dozen', 'Pack'
  final double price;
  final double total;

  const SupplierPurchaseItemEntity({
    this.productId = '',
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.total,
  });
}

class SupplierPurchaseEntity {
  final String id;
  final String supplierId;
  final String supplierName;
  final DateTime date;
  final List<SupplierPurchaseItemEntity> items;
  final double totalAmount;
  final double amountPaid;
  final String userId;
  final bool pendingSync;

  const SupplierPurchaseEntity({
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

  bool get isPaymentTransaction =>
      items.isEmpty && totalAmount == 0 && amountPaid > 0;

  double get dueAmount =>
      (totalAmount - amountPaid).clamp(0.0, double.infinity);

  SupplierPurchaseEntity copyWith({
    String? id,
    String? supplierId,
    String? supplierName,
    DateTime? date,
    List<SupplierPurchaseItemEntity>? items,
    double? totalAmount,
    double? amountPaid,
    String? userId,
    bool? pendingSync,
  }) {
    return SupplierPurchaseEntity(
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
