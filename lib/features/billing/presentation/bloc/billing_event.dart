import 'package:equatable/equatable.dart';

/// الأحداث الخاصة بإدارة الفاتورة والسلة
abstract class BillingEvent extends Equatable {
  const BillingEvent();

  @override
  List<Object?> get props => [];
}

/// إضافة منتج إلى السلة
class AddToCartEvent extends BillingEvent {
  final dynamic product;
  final int quantity;

  const AddToCartEvent({
    required this.product,
    this.quantity = 1,
  });

  @override
  List<Object?> get props => [
        product,
        quantity,
      ];
}

/// إزالة منتج من السلة
class RemoveFromCartEvent extends BillingEvent {
  final dynamic product;

  const RemoveFromCartEvent({
    required this.product,
  });

  @override
  List<Object?> get props => [
        product,
      ];
}

/// زيادة كمية منتج في السلة
class IncreaseQuantityEvent extends BillingEvent {
  final dynamic product;

  const IncreaseQuantityEvent({
    required this.product,
  });

  @override
  List<Object?> get props => [
        product,
      ];
}

/// إنقاص كمية منتج في السلة
class DecreaseQuantityEvent extends BillingEvent {
  final dynamic product;

  const DecreaseQuantityEvent({
    required this.product,
  });

  @override
  List<Object?> get props => [
        product,
      ];
}

/// تغيير كمية منتج مباشرة
class UpdateQuantityEvent extends BillingEvent {
  final dynamic product;
  final int quantity;

  const UpdateQuantityEvent({
    required this.product,
    required this.quantity,
  });

  @override
  List<Object?> get props => [
        product,
        quantity,
      ];
}

/// تفريغ السلة بالكامل
class ClearCartEvent extends BillingEvent {
  const ClearCartEvent();
}

/// إنهاء وحفظ الفاتورة
///
/// هذا الحدث يحل محل PrintReceiptEvent.
/// لا توجد أي عملية طباعة هنا.
class CompleteSaleEvent extends BillingEvent {
  const CompleteSaleEvent();
}

/// تحميل المنتجات من قاعدة البيانات المحلية Hive
class LoadProductsEvent extends BillingEvent {
  const LoadProductsEvent();
}

/// البحث عن منتج
class SearchProductsEvent extends BillingEvent {
  final String query;

  const SearchProductsEvent({
    required this.query,
  });

  @override
  List<Object?> get props => [
        query,
      ];
}

/// اختيار منتج من شاشة الكاشير اليدوية
///
/// عند الضغط على بطاقة المنتج يتم إرسال هذا الحدث
/// لإضافته مباشرة إلى السلة.
class SelectProductEvent extends BillingEvent {
  final dynamic product;

  const SelectProductEvent({
    required this.product,
  });

  @override
  List<Object?> get props => [
        product,
      ];
}

/// إعادة تعيين حالة البحث
class ClearSearchEvent extends BillingEvent {
  const ClearSearchEvent();
}
