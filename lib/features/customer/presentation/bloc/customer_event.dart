import '../../domain/entities/customer_entity.dart';

abstract class CustomerEvent {}

class LoadCustomersEvent extends CustomerEvent {}

class AddCustomerEvent extends CustomerEvent {
  final CustomerEntity customer;
  AddCustomerEvent(this.customer);
}

class UpdateCustomerEvent extends CustomerEvent {
  final CustomerEntity customer;
  UpdateCustomerEvent(this.customer);
}

class DeleteCustomerEvent extends CustomerEvent {
  final String id;
  DeleteCustomerEvent(this.id);
}
