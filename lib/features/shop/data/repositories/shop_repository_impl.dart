import 'dart:async';

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

      // Always mark as pending BEFORE attempting the push.
      // pushShop() will clear this flag on success. This guarantees that
      // if the push fails for any reason (auth race, Firestore error, etc.)
      // the next sync cycle will pick it up and retry.
      await _syncService.markShopPendingSync();

      if (_syncService.isOnline) {
        // Push in the background; pendingShopSync is cleared inside pushShop
        // on success, or stays true on failure so the next cycle retries it.
        unawaited(_syncService.pushShop(model));
      }

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
