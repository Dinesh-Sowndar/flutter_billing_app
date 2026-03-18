class CustomerEntity {
  final String id;
  final String name;
  final String phone;
  final double balance; // Added balance for ledger
  final bool pendingSync;

  const CustomerEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.balance = 0.0, // Default to 0
    this.pendingSync = false,
  });

  CustomerEntity copyWith({
    String? id,
    String? name,
    String? phone,
    double? balance,
    bool? pendingSync,
  }) {
    return CustomerEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      balance: balance ?? this.balance,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CustomerEntity && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
