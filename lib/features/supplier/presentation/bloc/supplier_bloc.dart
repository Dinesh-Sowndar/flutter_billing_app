import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/supplier_usecases.dart';
import 'supplier_event.dart';
import 'supplier_state.dart';

class SupplierBloc extends Bloc<SupplierEvent, SupplierState> {
  final GetSuppliersUseCase getSuppliersUseCase;
  final AddSupplierUseCase addSupplierUseCase;
  final UpdateSupplierUseCase updateSupplierUseCase;
  final DeleteSupplierUseCase deleteSupplierUseCase;

  SupplierBloc({
    required this.getSuppliersUseCase,
    required this.addSupplierUseCase,
    required this.updateSupplierUseCase,
    required this.deleteSupplierUseCase,
  }) : super(const SupplierState()) {
    on<LoadSuppliersEvent>(_onLoad);
    on<AddSupplierEvent>(_onAdd);
    on<UpdateSupplierEvent>(_onUpdate);
    on<DeleteSupplierEvent>(_onDelete);
  }

  Future<void> _onLoad(
      LoadSuppliersEvent event, Emitter<SupplierState> emit) async {
    emit(state.copyWith(status: SupplierStatus.loading));
    try {
      final suppliers = await getSuppliersUseCase();
      emit(state.copyWith(status: SupplierStatus.loaded, suppliers: suppliers));
    } catch (e) {
      emit(state.copyWith(status: SupplierStatus.error, error: e.toString()));
    }
  }

  Future<void> _onAdd(
      AddSupplierEvent event, Emitter<SupplierState> emit) async {
    try {
      await addSupplierUseCase(event.supplier);
      final suppliers = await getSuppliersUseCase();
      emit(state.copyWith(status: SupplierStatus.loaded, suppliers: suppliers));
    } catch (e) {
      emit(state.copyWith(status: SupplierStatus.error, error: e.toString()));
    }
  }

  Future<void> _onUpdate(
      UpdateSupplierEvent event, Emitter<SupplierState> emit) async {
    try {
      await updateSupplierUseCase(event.supplier);
      final suppliers = await getSuppliersUseCase();
      emit(state.copyWith(status: SupplierStatus.loaded, suppliers: suppliers));
    } catch (e) {
      emit(state.copyWith(status: SupplierStatus.error, error: e.toString()));
    }
  }

  Future<void> _onDelete(
      DeleteSupplierEvent event, Emitter<SupplierState> emit) async {
    try {
      await deleteSupplierUseCase(event.id);
      final suppliers = await getSuppliersUseCase();
      emit(state.copyWith(status: SupplierStatus.loaded, suppliers: suppliers));
    } catch (e) {
      emit(state.copyWith(status: SupplierStatus.error, error: e.toString()));
    }
  }
}
