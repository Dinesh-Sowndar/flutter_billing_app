import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:billing_app/features/billing/domain/entities/cart_item.dart';
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

  bool _isWeightedUnit(QuantityUnit unit) =>
      unit == QuantityUnit.kg || unit == QuantityUnit.liter;

  double _stepForUnit(QuantityUnit unit) => 1.0;

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
      final increment = _stepForUnit(existingItem.product.unit);
      backendItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + increment,
      );
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
      customerDue: event.customerDue,
    ));
  }

  Future<void> _onFinishTransaction(
      FinishTransactionEvent event, Emitter<BillingState> emit) async {
    emit(state.copyWith(clearError: true));
    try {
      final grandTotal =
          (state.totalAmount + state.customerDue).toDouble();
      final normalizedAmountPaid =
          event.amountPaid.clamp(0.0, grandTotal).toDouble();
      // ── GST computation ────────────────────────────────────────────
      final settingsBox = HiveDatabase.settingsBox;
      final gstEnabled = settingsBox.get('gst_enabled', defaultValue: false) as bool;
      final gstRate = gstEnabled
          ? (settingsBox.get('gst_rate', defaultValue: 0.0) as num).toDouble()
          : 0.0;
      double cgstAmount = 0.0;
      double sgstAmount = 0.0;
      String gstNumber = '';
      if (gstEnabled && gstRate > 0) {
        // Back-calculate tax from inclusive price
        final taxableAmount = state.totalAmount / (1 + gstRate / 100);
        final totalTax = state.totalAmount - taxableAmount;
        cgstAmount = double.parse((totalTax / 2).toStringAsFixed(2));
        sgstAmount = double.parse((totalTax / 2).toStringAsFixed(2));
        // Read GSTIN from shop
        final shopModel = HiveDatabase.shopBox.values.isNotEmpty
            ? HiveDatabase.shopBox.values.first
            : null;
        gstNumber = shopModel?.gstNumber ?? '';
      }
      // ───────────────────────────────────────────────────────────────

      final transaction = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        totalAmount: state.totalAmount,
        customerId: state.customerId,
        customerName: state.customerName,
        amountPaid: normalizedAmountPaid,
        paymentMethod: event.paymentMethod,
        gstRate: gstRate,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        gstNumber: gstNumber,
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
        final stockDelta = item.product.unit == QuantityUnit.piece ||
                item.product.unit == QuantityUnit.box
            ? item.quantity.round()
            : item.quantity.floor();
        final newStock = item.product.stock - stockDelta;
        await updateProductUseCase(
          item.product.copyWith(stock: newStock >= 0 ? newStock : 0),
        );
      }

      // Update customer balance if applicable
      if (state.customerId.isNotEmpty) {
        final newBalance =
            (grandTotal - normalizedAmountPaid).clamp(0.0, grandTotal).toDouble();
        // Direct Hive update — no entity roundtrip, no userId lookup
        final existingModel = HiveDatabase.customerBox.get(state.customerId);
        if (existingModel != null) {
          await HiveDatabase.customerBox.put(
            state.customerId,
            existingModel.copyWith(balance: newBalance),
          );
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

    // ── Ensure printer is connected (with retry) ─────────────────────────
    if (!printerHelper.isConnected) {
      // Check if BT link is actually still alive (singleton flag can be stale)
      final btStatus = await PrintBluetoothThermal.connectionStatus;
      if (!btStatus) {
        final savedMac = HiveDatabase.settingsBox.get('printer_mac');
        if (savedMac == null) {
          emit(state.copyWith(
              error: 'No printer saved. Go to Settings → Printer to pair one.',
              clearError: false));
          emit(state.copyWith(clearError: true));
          return;
        }

        // Retry up to 3 times with 800 ms gap
        bool connected = false;
        for (int attempt = 1; attempt <= 3; attempt++) {
          connected = await printerHelper.connect(savedMac);
          if (connected) break;
          if (attempt < 3) {
            await Future.delayed(const Duration(milliseconds: 800));
          }
        }

        if (!connected) {
          emit(state.copyWith(
              error:
                  'Could not connect to printer after 3 attempts. Make sure it is on and paired.',
              clearError: false));
          emit(state.copyWith(clearError: true));
          return;
        }
      }
    }
    // ─────────────────────────────────────────────────────────────────────


    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      final grandTotal =
          (state.totalAmount + state.customerDue).toDouble();
      final normalizedAmountPaid =
          event.amountPaid.clamp(0.0, grandTotal).toDouble();

      // ── GST computation ────────────────────────────────────────────
      final settingsBox = HiveDatabase.settingsBox;
      final gstEnabled = settingsBox.get('gst_enabled', defaultValue: false) as bool;
      final gstRate = gstEnabled
          ? (settingsBox.get('gst_rate', defaultValue: 0.0) as num).toDouble()
          : 0.0;
      double cgstAmount = 0.0;
      double sgstAmount = 0.0;
      String gstNumber = '';
      if (gstEnabled && gstRate > 0) {
        final taxableAmount = state.totalAmount / (1 + gstRate / 100);
        final totalTax = state.totalAmount - taxableAmount;
        cgstAmount = double.parse((totalTax / 2).toStringAsFixed(2));
        sgstAmount = double.parse((totalTax / 2).toStringAsFixed(2));
        final shopModel = HiveDatabase.shopBox.values.isNotEmpty
            ? HiveDatabase.shopBox.values.first
            : null;
        gstNumber = shopModel?.gstNumber ?? '';
      }
      // ───────────────────────────────────────────────────────────────

      // ── 1. Save transaction ─────────────────────────────────────────
      final transaction = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        totalAmount: state.totalAmount,
        customerId: state.customerId,
        customerName: state.customerName,
        amountPaid: normalizedAmountPaid,
        paymentMethod: event.paymentMethod,
        gstRate: gstRate,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        gstNumber: gstNumber,
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

      // ── 2. Decrease stock ───────────────────────────────────────────
      for (final item in state.cartItems) {
        final stockDelta = item.product.unit == QuantityUnit.piece ||
                item.product.unit == QuantityUnit.box
            ? item.quantity.round()
            : item.quantity.floor();
        final newStock = item.product.stock - stockDelta;
        await updateProductUseCase(
          item.product.copyWith(stock: newStock >= 0 ? newStock : 0),
        );
      }

      // ── 3. Update customer balance ──────────────────────────────────
      if (state.customerId.isNotEmpty) {
        final newBalance =
            (grandTotal - normalizedAmountPaid).clamp(0.0, grandTotal).toDouble();
        // Direct Hive update — no entity roundtrip, no userId lookup
        final existingModel = HiveDatabase.customerBox.get(state.customerId);
        if (existingModel != null) {
          await HiveDatabase.customerBox.put(
            state.customerId,
            existingModel.copyWith(balance: newBalance),
          );
        }
      }

      // ── 4. Print receipt ────────────────────────────────────────────
      //  Verify BT link is still alive right before sending bytes
      final btAlive = await PrintBluetoothThermal.connectionStatus;
      if (!btAlive) {
        // Transaction is already saved — just surface the print failure
        emit(state.copyWith(
            isPrinting: false,
            printSuccess: true, // transaction done
            error: 'Transaction saved but printer disconnected. '
                'Reconnect in Settings and reprint if needed.',
            clearError: false));
        emit(state.copyWith(clearError: true));
        return;
      }

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
          prevDue: state.customerDue,
          amountPaid: normalizedAmountPaid,
          customerName: state.customerName,
          paymentMethod: event.paymentMethod,
          upiId: event.upiId,
          footer: event.footer,
          gstRate: gstRate,
          cgstAmount: cgstAmount,
          sgstAmount: sgstAmount,
          gstNumber: gstNumber);
      // ───────────────────────────────────────────────────────────────

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Print failed: $e', clearError: false));
      // Reset error instantly avoids sticky error
      emit(state.copyWith(clearError: true));
    }
  }
}
