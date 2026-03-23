import '../../domain/entities/supplier_purchase_entity.dart';

enum SupplierPurchaseStatus { initial, loading, loaded, error }

class SupplierPurchaseState {
  final SupplierPurchaseStatus status;
  final List<SupplierPurchaseEntity> purchases;
  final String? error;

  const SupplierPurchaseState({
    this.status = SupplierPurchaseStatus.initial,
    this.purchases = const [],
    this.error,
  });

  SupplierPurchaseState copyWith({
    SupplierPurchaseStatus? status,
    List<SupplierPurchaseEntity>? purchases,
    String? error,
  }) {
    return SupplierPurchaseState(
      status: status ?? this.status,
      purchases: purchases ?? this.purchases,
      error: error ?? this.error,
    );
  }
}
