import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customer_repository.dart';
import '../models/customer_model.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final SyncService _syncService;

  CustomerRepositoryImpl({required SyncService syncService})
      : _syncService = syncService;

  @override
  Future<List<CustomerEntity>> getCustomers() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return HiveDatabase.customerBox.values
        .where((c) => c.userId == userId)
        .map((c) => c.toEntity())
        .toList();
  }

  @override
  Future<void> addCustomer(CustomerEntity customer) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final model = CustomerModel(
      id: customer.id,
      name: customer.name,
      phone: customer.phone,
      userId: userId,
      pendingSync: !_syncService.isOnline,
    );
    await HiveDatabase.customerBox.put(model.id, model);

    if (_syncService.isOnline) {
      await _syncService.pushCustomer(model);
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await HiveDatabase.customerBox.delete(id);
  }
}
