import '../../domain/entities/supplier_entity.dart';

enum SupplierStatus { initial, loading, loaded, error }

class SupplierState {
  final SupplierStatus status;
  final List<SupplierEntity> suppliers;
  final String? error;

  const SupplierState({
    this.status = SupplierStatus.initial,
    this.suppliers = const [],
    this.error,
  });

  SupplierState copyWith({
    SupplierStatus? status,
    List<SupplierEntity>? suppliers,
    String? error,
  }) {
    return SupplierState(
      status: status ?? this.status,
      suppliers: suppliers ?? this.suppliers,
      error: error ?? this.error,
    );
  }
}
