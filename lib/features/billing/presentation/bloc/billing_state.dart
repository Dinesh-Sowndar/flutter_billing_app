part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;

  const BillingState({
    this.cartItems = const [],
    this.error,
  });

  /// إجمالي الفاتورة.
  double get totalAmount {
    return cartItems.fold(
      0,
      (sum, item) => sum + item.total,
    );
  }

  /// إجمالي عدد القطع.
  int get totalQuantity {
    return cartItems.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
  }

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError
          ? null
          : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        cartItems,
        error,
      ];
}
