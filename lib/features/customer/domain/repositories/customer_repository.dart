import '../entities/customer_entity.dart';

abstract class CustomerRepository {
  Future<List<CustomerEntity>> getCustomers();
  Future<CustomerEntity?> getCustomerById(String id);
  Future<void> addCustomer(CustomerEntity customer);
  Future<void> updateCustomer(CustomerEntity customer);
  Future<void> deleteCustomer(String id);
}
