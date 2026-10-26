import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';

const List<Product> _sampleMenu = [
  Product(
    id: 'sample-roasted-tomato-toast',
    name: 'Roasted tomato toast',
    barcode: 'DEMO-001',
    price: 8.5,
    category: 'Small plates',
    description:
        'Sourdough, slow-roasted tomatoes, whipped ricotta and garden herbs.',
  ),
  Product(
    id: 'sample-crispy-chicken',
    name: 'Crispy chicken sandwich',
    barcode: 'DEMO-002',
    price: 13.0,
    category: 'Mains',
    description:
        'Buttermilk chicken, crunchy slaw, pickles and a bright house sauce.',
  ),
  Product(
    id: 'sample-market-bowl',
    name: 'Market greens bowl',
    barcode: 'DEMO-003',
    price: 11.5,
    category: 'Mains',
    description:
        'A changing mix of greens, grains, crisp vegetables and lemon dressing.',
  ),
  Product(
    id: 'sample-rosemary-fries',
    name: 'Rosemary fries',
    barcode: 'DEMO-004',
    price: 5.0,
    category: 'Sides',
    description: 'Golden-cut potatoes with rosemary salt and garlic aioli.',
  ),
  Product(
    id: 'sample-lemon-tart',
    name: 'Lemon olive-oil cake',
    barcode: 'DEMO-005',
    price: 7.0,
    category: 'Something sweet',
    description: 'Soft citrus cake finished with seasonal fruit.',
  ),
  Product(
    id: 'sample-cold-brew',
    name: 'Cold brew',
    barcode: 'DEMO-006',
    price: 4.5,
    category: 'Drinks',
    description: 'Slow-steeped coffee, served over ice.',
  ),
];

class ProductRepositoryImpl implements ProductRepository {
  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    try {
      final box = HiveDatabase.productBox;
      final settings = HiveDatabase.settingsBox;
      if (settings.get('sample_menu_initialized') != true) {
        if (box.isEmpty) {
          for (final product in _sampleMenu) {
            final model = ProductModel.fromEntity(product);
            await box.put(model.id, model);
          }
        }
        await settings.put('sample_menu_initialized', true);
      }
      final products = box.values.toList();
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
        (element) => element.barcode == barcode,
        orElse: () => throw Exception('Product not found'),
      );
      return Right(product);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addProduct(Product product) async {
    try {
      final box = HiveDatabase.productBox;
      // You can use add() or put()
      final model = ProductModel.fromEntity(product);
      await box.put(model.id, model); // Using ID as key
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateProduct(Product product) async {
    try {
      final box = HiveDatabase.productBox;
      final model = ProductModel.fromEntity(product);
      await box.put(model.id, model);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    try {
      final box = HiveDatabase.productBox;
      await box.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
