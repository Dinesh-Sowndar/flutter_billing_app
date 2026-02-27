part of 'product_bloc.dart';

enum ProductStatus { initial, loading, loaded, error, success }

class ProductState extends Equatable {
  final ProductStatus status;
  final List<Product> products;
  final String? message;

  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const [],
    this.message,
  });

  ProductState copyWith({
    ProductStatus? status,
    List<Product>? products,
    String? message,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      message:
          message, // Allow clearing message if not passed? No, usually distinct event.
      // But for copyWith, let's say if message passed is null, we keep it?
      // Or we want to set it to null?
      // Let's assume transient message.
    );
  }

  @override
  List<Object?> get props => [status, products, message];
}
