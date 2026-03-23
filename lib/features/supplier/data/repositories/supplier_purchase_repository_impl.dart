import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../domain/entities/supplier_purchase_entity.dart';
import '../../domain/repositories/supplier_purchase_repository.dart';
import '../models/supplier_purchase_model.dart';
import '../../../product/data/models/product_model.dart';

class SupplierPurchaseRepositoryImpl implements SupplierPurchaseRepository {
  final SyncService _syncService;

  SupplierPurchaseRepositoryImpl({required SyncService syncService})
      : _syncService = syncService;

  @override
  Future<List<SupplierPurchaseEntity>> getPurchasesBySupplier(
      String supplierId) async {
    return HiveDatabase.supplierPurchaseBox.values
        .where((p) => p.supplierId == supplierId)
        .map((p) => p.toEntity())
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> addPurchase(SupplierPurchaseEntity purchase) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final model = SupplierPurchaseModel.fromEntity(purchase, userId: userId)
        .copyWith(pendingSync: !_syncService.isOnline, userId: userId);
    await HiveDatabase.supplierPurchaseBox.put(model.id, model);

    // Update supplier balance (due = total - paid)
    final supplierModel = HiveDatabase.supplierBox.get(purchase.supplierId);
    if (supplierModel != null) {
      final due = purchase.totalAmount - purchase.amountPaid;
      final updatedSupplier = supplierModel.copyWith(
        balance: supplierModel.balance + due,
        pendingSync: !_syncService.isOnline,
      );
      await HiveDatabase.supplierBox.put(updatedSupplier.id, updatedSupplier);
      if (_syncService.isOnline) {
        await _syncService.pushSupplier(updatedSupplier);
      }
    }

    // ── Increment product stock for each purchased item ──────────────────
    for (final item in purchase.items) {
      if (item.productId.isEmpty) continue;
      final existing = HiveDatabase.productBox.get(item.productId);
      if (existing == null) continue;

      // Quantity is double (e.g. 1.5 kg) — ceil to nearest whole unit for stock
      final addedQty = item.quantity.ceil();
      final updated = ProductModel(
        id: existing.id,
        name: existing.name,
        barcode: existing.barcode,
        price: existing.price,
        stock: existing.stock + addedQty,
        unitIndex: existing.unitIndex,
        categoryId: existing.categoryId,
        pendingSync: !_syncService.isOnline,
      );
      await HiveDatabase.productBox.put(updated.id, updated);
      if (_syncService.isOnline) {
        await _syncService.pushProduct(updated);
      }
    }

    if (_syncService.isOnline) {
      await _syncService.pushSupplierPurchase(model);
    }
  }

  @override
  Future<void> deletePurchase(String id) async {
    await HiveDatabase.supplierPurchaseBox.delete(id);
    await _syncService.deleteSupplierPurchase(id);
  }
}
