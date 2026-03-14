import '../entities/customer_entity.dart';

abstract class CustomerRepository {
  Future<List<CustomerEntity>> getCustomers();
  Future<void> addCustomer(CustomerEntity customer);
  Future<void> deleteCustomer(String id);
}
