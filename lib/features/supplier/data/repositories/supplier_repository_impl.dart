import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../domain/entities/supplier_entity.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../models/supplier_model.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  final SyncService _syncService;

  SupplierRepositoryImpl({required SyncService syncService})
      : _syncService = syncService;

  @override
  Future<List<SupplierEntity>> getSuppliers() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return HiveDatabase.supplierBox.values
        .where((s) => s.userId == userId)
        .map((s) => s.toEntity())
        .toList();
  }

  @override
  Future<SupplierEntity?> getSupplierById(String id) async {
    final model = HiveDatabase.supplierBox.get(id);
    return model?.toEntity();
  }

  @override
  Future<void> addSupplier(SupplierEntity supplier) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Check for duplicate phone number among this user's suppliers
    final existingWithSamePhone = HiveDatabase.supplierBox.values.any(
      (s) => s.userId == userId && s.phone == supplier.phone,
    );
    if (existingWithSamePhone) {
      throw Exception('A supplier with phone number ${supplier.phone} already exists.');
    }

    final model = SupplierModel(
      id: supplier.id,
      name: supplier.name,
      phone: supplier.phone,
      userId: userId,
      balance: supplier.balance,
      pendingSync: !_syncService.isOnline,
    );
    await HiveDatabase.supplierBox.put(model.id, model);

    if (_syncService.isOnline) {
      await _syncService.pushSupplier(model);
    }
  }

  @override
  Future<void> updateSupplier(SupplierEntity supplier) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final model = SupplierModel(
      id: supplier.id,
      name: supplier.name,
      phone: supplier.phone,
      userId: userId,
      balance: supplier.balance,
      pendingSync: !_syncService.isOnline,
    );
    await HiveDatabase.supplierBox.put(model.id, model);

    if (_syncService.isOnline) {
      await _syncService.pushSupplier(model);
    }
  }

  @override
  Future<void> deleteSupplier(String id) async {
    await HiveDatabase.supplierBox.delete(id);
    await _syncService.deleteSupplier(id);
  }
}
