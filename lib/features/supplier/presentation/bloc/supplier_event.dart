import 'package:equatable/equatable.dart';
import '../../domain/entities/supplier_entity.dart';

abstract class SupplierEvent extends Equatable {
  const SupplierEvent();
  @override
  List<Object?> get props => [];
}

class LoadSuppliersEvent extends SupplierEvent {
  const LoadSuppliersEvent();
}

class AddSupplierEvent extends SupplierEvent {
  final SupplierEntity supplier;
  const AddSupplierEvent(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class UpdateSupplierEvent extends SupplierEvent {
  final SupplierEntity supplier;
  const UpdateSupplierEvent(this.supplier);
  @override
  List<Object?> get props => [supplier];
}

class DeleteSupplierEvent extends SupplierEvent {
  final String id;
  const DeleteSupplierEvent(this.id);
  @override
  List<Object?> get props => [id];
}
