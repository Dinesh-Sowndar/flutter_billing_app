import 'package:fpdart/fpdart.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/services/sync_service.dart';
import '../../domain/entities/shop.dart';
import '../../domain/repositories/shop_repository.dart';
import '../models/shop_model.dart';

class ShopRepositoryImpl implements ShopRepository {
  final SyncService _syncService;
  static const String shopKey = 'shop_details';

  ShopRepositoryImpl({required SyncService syncService})
      : _syncService = syncService;

  @override
  Future<Either<Failure, Shop>> getShop() async {
    try {
      final box = HiveDatabase.shopBox;
      final shop = box.get(shopKey);
      if (shop != null) {
        return Right(shop);
      } else {
        // Return default shop if not found
        return const Right(Shop(
            name: '',
            addressLine1: '',
            addressLine2: '',
            phoneNumber: '',
            upiId: '',
            footerText: ''));
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateShop(Shop shop) async {
    try {
      final box = HiveDatabase.shopBox;
      final model = ShopModel.fromEntity(shop);
      await box.put(shopKey, model);

      // Offline-first: save locally and defer cloud push when offline.
      if (!_syncService.isOnline) {
        await _syncService.markShopPendingSync();
        return const Right(null);
      }

      // Even if this push is slow/fails, keep local save successful.
      try {
        await _syncService.pushShop(model).timeout(const Duration(seconds: 6));
      } catch (_) {
        await _syncService.markShopPendingSync();
      }

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
