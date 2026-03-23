import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/supplier_purchase_usecases.dart';
import 'supplier_purchase_event.dart';
import 'supplier_purchase_state.dart';

class SupplierPurchaseBloc
    extends Bloc<SupplierPurchaseEvent, SupplierPurchaseState> {
  final GetPurchasesBySupplierUseCase getPurchasesBySupplierUseCase;
  final AddSupplierPurchaseUseCase addSupplierPurchaseUseCase;
  final DeleteSupplierPurchaseUseCase deleteSupplierPurchaseUseCase;

  SupplierPurchaseBloc({
    required this.getPurchasesBySupplierUseCase,
    required this.addSupplierPurchaseUseCase,
    required this.deleteSupplierPurchaseUseCase,
  }) : super(const SupplierPurchaseState()) {
    on<LoadSupplierPurchasesEvent>(_onLoad);
    on<AddSupplierPurchaseEvent>(_onAdd);
    on<DeleteSupplierPurchaseEvent>(_onDelete);
  }

  Future<void> _onLoad(LoadSupplierPurchasesEvent event,
      Emitter<SupplierPurchaseState> emit) async {
    emit(state.copyWith(status: SupplierPurchaseStatus.loading));
    try {
      final purchases = await getPurchasesBySupplierUseCase(event.supplierId);
      emit(state.copyWith(
          status: SupplierPurchaseStatus.loaded, purchases: purchases));
    } catch (e) {
      emit(state.copyWith(
          status: SupplierPurchaseStatus.error, error: e.toString()));
    }
  }

  Future<void> _onAdd(
      AddSupplierPurchaseEvent event, Emitter<SupplierPurchaseState> emit) async {
    try {
      await addSupplierPurchaseUseCase(event.purchase);
      final purchases =
          await getPurchasesBySupplierUseCase(event.supplierId);
      emit(state.copyWith(
          status: SupplierPurchaseStatus.loaded, purchases: purchases));
    } catch (e) {
      emit(state.copyWith(
          status: SupplierPurchaseStatus.error, error: e.toString()));
    }
  }

  Future<void> _onDelete(DeleteSupplierPurchaseEvent event,
      Emitter<SupplierPurchaseState> emit) async {
    try {
      await deleteSupplierPurchaseUseCase(event.id);
      final purchases =
          await getPurchasesBySupplierUseCase(event.supplierId);
      emit(state.copyWith(
          status: SupplierPurchaseStatus.loaded, purchases: purchases));
    } catch (e) {
      emit(state.copyWith(
          status: SupplierPurchaseStatus.error, error: e.toString()));
    }
  }
}
