class CustomerEntity {
  final String id;
  final String name;
  final String phone;
  final bool pendingSync;

  const CustomerEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.pendingSync = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CustomerEntity && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
