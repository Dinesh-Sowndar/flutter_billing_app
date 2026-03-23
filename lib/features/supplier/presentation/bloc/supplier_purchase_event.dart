import 'package:equatable/equatable.dart';
import '../../domain/entities/supplier_purchase_entity.dart';

abstract class SupplierPurchaseEvent extends Equatable {
  const SupplierPurchaseEvent();
  @override
  List<Object?> get props => [];
}

class LoadSupplierPurchasesEvent extends SupplierPurchaseEvent {
  final String supplierId;
  const LoadSupplierPurchasesEvent(this.supplierId);
  @override
  List<Object?> get props => [supplierId];
}

class AddSupplierPurchaseEvent extends SupplierPurchaseEvent {
  final SupplierPurchaseEntity purchase;
  final String supplierId;
  const AddSupplierPurchaseEvent({required this.purchase, required this.supplierId});
  @override
  List<Object?> get props => [purchase, supplierId];
}

class DeleteSupplierPurchaseEvent extends SupplierPurchaseEvent {
  final String id;
  final String supplierId;
  const DeleteSupplierPurchaseEvent({required this.id, required this.supplierId});
  @override
  List<Object?> get props => [id, supplierId];
}
