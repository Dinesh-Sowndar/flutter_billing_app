import '../../domain/entities/customer_entity.dart';

enum CustomerStatus { initial, loading, loaded, error }

class CustomerState {
  final CustomerStatus status;
  final List<CustomerEntity> customers;
  final String? error;

  const CustomerState({
    this.status = CustomerStatus.initial,
    this.customers = const [],
    this.error,
  });

  CustomerState copyWith({
    CustomerStatus? status,
    List<CustomerEntity>? customers,
    String? error,
  }) {
    return CustomerState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      error: error ?? this.error,
    );
  }
}
