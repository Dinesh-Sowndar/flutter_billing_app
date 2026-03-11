import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/services/sync_service.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final SyncService syncService;

  ProductRepositoryImpl({required this.syncService});

  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    try {
      // If online, do a fresh pull first so we have the latest data.
      if (syncService.isOnline) {
        await syncService.pullProductsFromFirestore();
      }
      final box = HiveDatabase.productBox;
      final products = box.values.map((m) => m.toEntity()).toList();
      return Right(products);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Product>> getProductByBarcode(String barcode) async {
    try {
      final box = HiveDatabase.productBox;
      final product = box.values.firstWhere(
        (element) => element.barcode == barcode || element.id == barcode,
        orElse: () => throw Exception('Product not found'),
      );
      return Right(product.toEntity());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addProduct(Product product) async {
    try {
      final model = ProductModel.fromEntity(
        product.copyWith(pendingSync: !syncService.isOnline),
      );
      await HiveDatabase.productBox.put(model.id, model);
      if (syncService.isOnline) {
        await syncService.pushProduct(model);
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateProduct(Product product) async {
    try {
      final model = ProductModel.fromEntity(
        product.copyWith(pendingSync: !syncService.isOnline),
      );
      await HiveDatabase.productBox.put(model.id, model);
      if (syncService.isOnline) {
        await syncService.pushProduct(model);
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    try {
      await HiveDatabase.productBox.delete(id);
      if (syncService.isOnline) {
        await syncService.deleteProduct(id);
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}

