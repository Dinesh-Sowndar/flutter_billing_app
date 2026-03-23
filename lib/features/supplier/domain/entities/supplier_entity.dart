class SupplierEntity {
  final String id;
  final String name;
  final String phone;
  final double balance; // Amount we owe this supplier (positive = we owe them)
  final bool pendingSync;

  const SupplierEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.balance = 0.0,
    this.pendingSync = false,
  });

  SupplierEntity copyWith({
    String? id,
    String? name,
    String? phone,
    double? balance,
    bool? pendingSync,
  }) {
    return SupplierEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      balance: balance ?? this.balance,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SupplierEntity && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
