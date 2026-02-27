import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class GetProductsUseCase implements UseCase<List<Product>, NoParams> {
  final ProductRepository repository;

  GetProductsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Product>>> call(NoParams params) {
    return repository.getProducts();
  }
}

class AddProductUseCase implements UseCase<void, Product> {
  final ProductRepository repository;

  AddProductUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(Product params) {
    return repository.addProduct(params);
  }
}

class UpdateProductUseCase implements UseCase<void, Product> {
  final ProductRepository repository;

  UpdateProductUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(Product params) {
    return repository.updateProduct(params);
  }
}

class DeleteProductUseCase implements UseCase<void, String> {
  final ProductRepository repository;

  DeleteProductUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.deleteProduct(params);
  }
}

class GetProductByBarcodeUseCase implements UseCase<Product, String> {
  final ProductRepository repository;

  GetProductByBarcodeUseCase(this.repository);

  @override
  Future<Either<Failure, Product>> call(String params) {
    return repository.getProductByBarcode(params);
  }
}
