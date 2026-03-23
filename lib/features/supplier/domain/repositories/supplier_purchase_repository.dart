import '../entities/supplier_purchase_entity.dart';

abstract class SupplierPurchaseRepository {
  Future<List<SupplierPurchaseEntity>> getPurchasesBySupplier(String supplierId);
  Future<void> addPurchase(SupplierPurchaseEntity purchase);
  Future<void> deletePurchase(String id);
}
