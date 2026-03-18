import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/data/hive_database.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/repositories/billing_repository.dart';
import '../../../customer/domain/repositories/customer_repository.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;
  final UpdateProductUseCase updateProductUseCase;
  final BillingRepository billingRepository;
  final CustomerRepository customerRepository;

  BillingBloc({
    required this.getProductByBarcodeUseCase,
    required this.updateProductUseCase,
    required this.billingRepository,
    required this.customerRepository,
  }) : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<ClearCartEvent>(_onClearCart);
    on<SetCustomerEvent>(_onSetCustomer);
    on<PrintReceiptEvent>(_onPrintReceipt);
    on<FinishTransactionEvent>(_onFinishTransaction);
  }

  Future<void> _onScanBarcode(
      ScanBarcodeEvent event, Emitter<BillingState> emit) async {
    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: 'Product not found: ${event.barcode}')),
      (product) {
        add(AddProductToCartEvent(product));
      },
    );
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    // Clear error when adding
    final cleanState = state.copyWith(error: null);

    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.product.id == event.product.id);
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] =
          existingItem.copyWith(quantity: existingItem.quantity + 1);
      emit(cleanState.copyWith(cartItems: backendItems, error: null));
    } else {
      final newItem = CartItem(product: event.product);
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem], error: null));
    }
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  void _onUpdateQuantity(
      UpdateQuantityEvent event, Emitter<BillingState> emit) {
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    emit(const BillingState());
  }

  void _onSetCustomer(SetCustomerEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(
      customerId: event.customerId,
      customerName: event.customerName,
    ));
  }

  Future<void> _onFinishTransaction(
      FinishTransactionEvent event, Emitter<BillingState> emit) async {
    emit(state.copyWith(clearError: true));
    try {
      final normalizedAmountPaid =
          event.amountPaid.clamp(0.0, state.totalAmount).toDouble();
      final transaction = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        totalAmount: state.totalAmount,
        customerId: state.customerId,
        customerName: state.customerName,
        amountPaid: normalizedAmountPaid,
        paymentMethod: event.paymentMethod,
        items: state.cartItems
            .map((item) => TransactionItemModel(
                  productId: item.product.id,
                  productName: item.product.name,
                  price: item.product.price,
                  quantity: item.quantity,
                  total: item.total,
                ))
            .toList(),
      );
      await billingRepository.saveTransaction(transaction);

      // Decrease stock for each item sold
      for (final item in state.cartItems) {
        final newStock = item.product.stock - item.quantity;
        await updateProductUseCase(
          item.product.copyWith(stock: newStock >= 0 ? newStock : 0),
        );
      }

      // Update customer balance if applicable
      if (state.customerId.isNotEmpty) {
        final dueAmount = (state.totalAmount - normalizedAmountPaid)
            .clamp(0.0, state.totalAmount)
            .toDouble();
        if (dueAmount > 0) {
          final customer =
              await customerRepository.getCustomerById(state.customerId);
          if (customer != null) {
            final updatedCustomer =
                customer.copyWith(balance: customer.balance + dueAmount);
            await customerRepository.updateCustomer(updatedCustomer);
          }
        }
      }

      emit(state.copyWith(printSuccess: true));
    } catch (e) {
      emit(state.copyWith(error: 'Transaction failed: $e', clearError: false));
      emit(state.copyWith(clearError: true));
    }
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    final printerHelper = PrinterHelper();

    if (!printerHelper.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          emit(state.copyWith(
              error: 'Failed to auto-connect to printer!', clearError: false));
          emit(state.copyWith(clearError: true));
          return;
        }
      } else {
        emit(state.copyWith(
            error: 'Printer not connected & no saved printer found!',
            clearError: false));
        emit(state.copyWith(clearError: true));
        return;
      }
    }

    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      final normalizedAmountPaid =
        event.amountPaid.clamp(0.0, state.totalAmount).toDouble();
      final items = state.cartItems
          .map((item) => {
                'name': item.product.name,
                'qty': item.quantity,
                'price': item.product.price,
                'total': item.total,
              })
          .toList();

      await printerHelper.printReceipt(
          shopName: event.shopName,
          address1: event.address1,
          address2: event.address2,
          phone: event.phone,
          items: items,
          total: state.totalAmount,
          footer: event.footer);

      final transaction = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        totalAmount: state.totalAmount,
        customerId: state.customerId,
        customerName: state.customerName,
        amountPaid: normalizedAmountPaid,
        paymentMethod: event.paymentMethod,
        items: state.cartItems
            .map((item) => TransactionItemModel(
                  productId: item.product.id,
                  productName: item.product.name,
                  price: item.product.price,
                  quantity: item.quantity,
                  total: item.total,
                ))
            .toList(),
      );
      await billingRepository.saveTransaction(transaction);

      // Decrease stock for each item sold
      for (final item in state.cartItems) {
        final newStock = item.product.stock - item.quantity;
        await updateProductUseCase(
          item.product.copyWith(stock: newStock >= 0 ? newStock : 0),
        );
      }

      // Update customer balance if applicable
      if (state.customerId.isNotEmpty) {
        final dueAmount = (state.totalAmount - normalizedAmountPaid)
            .clamp(0.0, state.totalAmount)
            .toDouble();
        if (dueAmount > 0) {
          final customer =
              await customerRepository.getCustomerById(state.customerId);
          if (customer != null) {
            final updatedCustomer =
                customer.copyWith(balance: customer.balance + dueAmount);
            await customerRepository.updateCustomer(updatedCustomer);
          }
        }
      }

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Print failed: $e', clearError: false));
      // Reset error instantly avoids sticky error
      emit(state.copyWith(clearError: true));
    }
  }
}
