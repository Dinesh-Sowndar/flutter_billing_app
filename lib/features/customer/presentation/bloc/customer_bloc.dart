import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/customer_usecases.dart';
import 'customer_event.dart';
import 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final GetCustomersUseCase getCustomersUseCase;
  final AddCustomerUseCase addCustomerUseCase;
  final UpdateCustomerUseCase updateCustomerUseCase;
  final DeleteCustomerUseCase deleteCustomerUseCase;

  CustomerBloc({
    required this.getCustomersUseCase,
    required this.addCustomerUseCase,
    required this.updateCustomerUseCase,
    required this.deleteCustomerUseCase,
  }) : super(const CustomerState()) {
    on<LoadCustomersEvent>(_onLoad);
    on<AddCustomerEvent>(_onAdd);
    on<UpdateCustomerEvent>(_onUpdate);
    on<DeleteCustomerEvent>(_onDelete);
  }

  Future<void> _onLoad(
      LoadCustomersEvent event, Emitter<CustomerState> emit) async {
    emit(state.copyWith(status: CustomerStatus.loading));
    try {
      final customers = await getCustomersUseCase();
      emit(state.copyWith(
          status: CustomerStatus.loaded, customers: customers));
    } catch (e) {
      emit(state.copyWith(
          status: CustomerStatus.error, error: e.toString()));
    }
  }

  Future<void> _onAdd(
      AddCustomerEvent event, Emitter<CustomerState> emit) async {
    try {
      await addCustomerUseCase(event.customer);
      final customers = await getCustomersUseCase();
      emit(state.copyWith(
          status: CustomerStatus.loaded, customers: customers));
    } catch (e) {
      emit(state.copyWith(
          status: CustomerStatus.error, error: e.toString()));
    }
  }

  Future<void> _onUpdate(
      UpdateCustomerEvent event, Emitter<CustomerState> emit) async {
    try {
      await updateCustomerUseCase(event.customer);
      final customers = await getCustomersUseCase();
      emit(state.copyWith(
          status: CustomerStatus.loaded, customers: customers));
    } catch (e) {
      emit(state.copyWith(
          status: CustomerStatus.error, error: e.toString()));
    }
  }

  Future<void> _onDelete(
      DeleteCustomerEvent event, Emitter<CustomerState> emit) async {
    try {
      await deleteCustomerUseCase(event.id);
      final customers = await getCustomersUseCase();
      emit(state.copyWith(
          status: CustomerStatus.loaded, customers: customers));
    } catch (e) {
      emit(state.copyWith(
          status: CustomerStatus.error, error: e.toString()));
    }
  }
}
