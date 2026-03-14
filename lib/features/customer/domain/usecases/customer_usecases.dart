import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class GetCustomersUseCase {
  final CustomerRepository repository;
  GetCustomersUseCase(this.repository);
  Future<List<CustomerEntity>> call() => repository.getCustomers();
}

class AddCustomerUseCase {
  final CustomerRepository repository;
  AddCustomerUseCase(this.repository);
  Future<void> call(CustomerEntity customer) => repository.addCustomer(customer);
}

class DeleteCustomerUseCase {
  final CustomerRepository repository;
  DeleteCustomerUseCase(this.repository);
  Future<void> call(String id) => repository.deleteCustomer(id);
}
