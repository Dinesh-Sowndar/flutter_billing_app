import '../entities/supplier_entity.dart';

abstract class SupplierRepository {
  Future<List<SupplierEntity>> getSuppliers();
  Future<SupplierEntity?> getSupplierById(String id);
  Future<void> addSupplier(SupplierEntity supplier);
  Future<void> updateSupplier(SupplierEntity supplier);
  Future<void> deleteSupplier(String id);
}
