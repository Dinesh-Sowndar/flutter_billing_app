import '../entities/supplier_purchase_entity.dart';
import '../repositories/supplier_purchase_repository.dart';

class GetPurchasesBySupplierUseCase {
  final SupplierPurchaseRepository repository;
  GetPurchasesBySupplierUseCase(this.repository);
  Future<List<SupplierPurchaseEntity>> call(String supplierId) =>
      repository.getPurchasesBySupplier(supplierId);
}

class AddSupplierPurchaseUseCase {
  final SupplierPurchaseRepository repository;
  AddSupplierPurchaseUseCase(this.repository);
  Future<void> call(SupplierPurchaseEntity purchase) =>
      repository.addPurchase(purchase);
}

class DeleteSupplierPurchaseUseCase {
  final SupplierPurchaseRepository repository;
  DeleteSupplierPurchaseUseCase(this.repository);
  Future<void> call(String id) => repository.deletePurchase(id);
}
