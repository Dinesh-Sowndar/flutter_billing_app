import '../entities/supplier_entity.dart';
import '../repositories/supplier_repository.dart';

class GetSuppliersUseCase {
  final SupplierRepository repository;
  GetSuppliersUseCase(this.repository);
  Future<List<SupplierEntity>> call() => repository.getSuppliers();
}

class GetSupplierByIdUseCase {
  final SupplierRepository repository;
  GetSupplierByIdUseCase(this.repository);
  Future<SupplierEntity?> call(String id) => repository.getSupplierById(id);
}

class AddSupplierUseCase {
  final SupplierRepository repository;
  AddSupplierUseCase(this.repository);
  Future<void> call(SupplierEntity supplier) => repository.addSupplier(supplier);
}

class UpdateSupplierUseCase {
  final SupplierRepository repository;
  UpdateSupplierUseCase(this.repository);
  Future<void> call(SupplierEntity supplier) => repository.updateSupplier(supplier);
}

class DeleteSupplierUseCase {
  final SupplierRepository repository;
  DeleteSupplierUseCase(this.repository);
  Future<void> call(String id) => repository.deleteSupplier(id);
}
