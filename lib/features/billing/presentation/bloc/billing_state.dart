part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final String customerId;
  final String customerName;
  final double customerDue; // Previous outstanding balance

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.customerId = '',
    this.customerName = '',
    this.customerDue = 0.0,
  });

  double get totalAmount => cartItems.fold(0, (sum, item) => sum + item.total);

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    String? customerId,
    String? customerName,
    double? customerDue,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerDue: customerDue ?? this.customerDue,
    );
  }

  @override
  List<Object?> get props =>
      [cartItems, error, isPrinting, printSuccess, customerId, customerName, customerDue];
}
