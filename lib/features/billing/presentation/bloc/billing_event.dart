part of 'billing_bloc.dart';

abstract class BillingEvent extends Equatable {
  const BillingEvent();
  @override
  List<Object> get props => [];
}

class ScanBarcodeEvent extends BillingEvent {
  final String barcode;
  const ScanBarcodeEvent(this.barcode);
  @override
  List<Object> get props => [barcode];
}

class AddProductToCartEvent extends BillingEvent {
  final Product product;
  const AddProductToCartEvent(this.product);
  @override
  List<Object> get props => [product];
}

class RemoveProductFromCartEvent extends BillingEvent {
  final String productId;
  const RemoveProductFromCartEvent(this.productId);
  @override
  List<Object> get props => [productId];
}

class UpdateQuantityEvent extends BillingEvent {
  final String productId;
  final double quantity;
  const UpdateQuantityEvent(this.productId, this.quantity);
  @override
  List<Object> get props => [productId, quantity];
}

class ClearCartEvent extends BillingEvent {}

class SetCustomerEvent extends BillingEvent {
  final String customerId;
  final String customerName;
  final double customerDue;
  const SetCustomerEvent({
      required this.customerId,
      required this.customerName,
      this.customerDue = 0.0});
  @override
  List<Object> get props => [customerId, customerName, customerDue];
}

class FinishTransactionEvent extends BillingEvent {
  final double amountPaid;
  final String paymentMethod;
  const FinishTransactionEvent(
      {this.amountPaid = 0.0, this.paymentMethod = 'cash'});

  @override
  List<Object> get props => [amountPaid, paymentMethod];
}

class PrintReceiptEvent extends BillingEvent {
  final String shopName;
  final String address1;
  final String address2;
  final String phone;
  final String footer;
  final double amountPaid;
  final String paymentMethod;
  final String upiId;

  const PrintReceiptEvent({
    required this.shopName,
    required this.address1,
    required this.address2,
    required this.phone,
    required this.footer,
    this.amountPaid = 0.0,
    this.paymentMethod = 'cash',
    this.upiId = '',
  });

  @override
  List<Object> get props =>
      [shopName, address1, address2, phone, footer, amountPaid, paymentMethod, upiId];
}
