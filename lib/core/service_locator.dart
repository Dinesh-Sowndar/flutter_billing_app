import 'package:get_it/get_it.dart';
import '../../features/product/data/repositories/product_repository_impl.dart';
import '../../features/product/domain/repositories/product_repository.dart';
import '../../features/product/domain/usecases/product_usecases.dart';
import '../../features/product/presentation/bloc/product_bloc.dart';
import '../../features/shop/data/repositories/shop_repository_impl.dart';
import '../../features/shop/domain/repositories/shop_repository.dart';
import '../../features/shop/domain/usecases/shop_usecases.dart';
import '../../features/shop/presentation/bloc/shop_bloc.dart';
import '../../features/settings/data/repositories/printer_repository_impl.dart';
import '../../features/settings/domain/repositories/printer_repository.dart';
import '../../features/settings/presentation/bloc/printer_bloc.dart';
import '../../features/billing/domain/repositories/billing_repository.dart';
import '../../features/billing/presentation/bloc/sales_bloc.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/firebase_auth_repository_impl.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/customer/data/repositories/customer_repository_impl.dart';
import '../../features/customer/domain/repositories/customer_repository.dart';
import '../../features/customer/domain/usecases/customer_usecases.dart';
import '../../features/customer/presentation/bloc/customer_bloc.dart';
import '../../features/supplier/data/repositories/supplier_repository_impl.dart';
import '../../features/supplier/data/repositories/supplier_purchase_repository_impl.dart';
import '../../features/supplier/domain/repositories/supplier_repository.dart';
import '../../features/supplier/domain/repositories/supplier_purchase_repository.dart';
import '../../features/supplier/domain/usecases/supplier_usecases.dart';
import '../../features/supplier/domain/usecases/supplier_purchase_usecases.dart';
import '../../features/supplier/presentation/bloc/supplier_bloc.dart';
import '../../features/supplier/presentation/bloc/supplier_purchase_bloc.dart';
import 'services/sync_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Core
  sl.registerLazySingleton<SyncService>(() => SyncService());

  sl.registerLazySingleton<BillingRepository>(
    () => BillingRepository(syncService: sl()),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => FirebaseAuthRepositoryImpl(),
  );

  sl.registerLazySingleton(
    () => AuthBloc(
      authRepository: sl(),
    ),
  );

  sl.registerFactory(
    () => SalesBloc(
      billingRepository: sl(),
    ),
  );

  // Features - Product
  sl.registerFactory(
    () => ProductBloc(
      getProductsUseCase: sl(),
      addProductUseCase: sl(),
      updateProductUseCase: sl(),
      deleteProductUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => ShopBloc(
      getShopUseCase: sl(),
      updateShopUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => PrinterBloc(
      repository: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetProductsUseCase(sl()));
  sl.registerLazySingleton(() => AddProductUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProductUseCase(sl()));
  sl.registerLazySingleton(() => DeleteProductUseCase(sl()));
  sl.registerLazySingleton(() => GetProductByBarcodeUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(syncService: sl()),
  );

  // Features - Shop
  sl.registerLazySingleton(() => GetShopUseCase(sl()));
  sl.registerLazySingleton(() => UpdateShopUseCase(sl()));
  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepositoryImpl(syncService: sl()),
  );

  // Features - Settings / Printer
  sl.registerLazySingleton<PrinterRepository>(
    () => PrinterRepositoryImpl(),
  );

  // Features - Customer
  sl.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(syncService: sl()),
  );
  sl.registerLazySingleton(() => GetCustomersUseCase(sl()));
  sl.registerLazySingleton(() => AddCustomerUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCustomerUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCustomerUseCase(sl()));
  sl.registerFactory(() => CustomerBloc(
        getCustomersUseCase: sl(),
        addCustomerUseCase: sl(),
        updateCustomerUseCase: sl(),
        deleteCustomerUseCase: sl(),
      ));

  // Features - Supplier
  sl.registerLazySingleton<SupplierRepository>(
    () => SupplierRepositoryImpl(syncService: sl()),
  );
  sl.registerLazySingleton(() => GetSuppliersUseCase(sl()));
  sl.registerLazySingleton(() => GetSupplierByIdUseCase(sl()));
  sl.registerLazySingleton(() => AddSupplierUseCase(sl()));
  sl.registerLazySingleton(() => UpdateSupplierUseCase(sl()));
  sl.registerLazySingleton(() => DeleteSupplierUseCase(sl()));
  sl.registerFactory(() => SupplierBloc(
        getSuppliersUseCase: sl(),
        addSupplierUseCase: sl(),
        updateSupplierUseCase: sl(),
        deleteSupplierUseCase: sl(),
      ));

  // Features - SupplierPurchase
  sl.registerLazySingleton<SupplierPurchaseRepository>(
    () => SupplierPurchaseRepositoryImpl(syncService: sl()),
  );
  sl.registerLazySingleton(() => GetPurchasesBySupplierUseCase(sl()));
  sl.registerLazySingleton(() => AddSupplierPurchaseUseCase(sl()));
  sl.registerLazySingleton(() => DeleteSupplierPurchaseUseCase(sl()));
  sl.registerFactory(() => SupplierPurchaseBloc(
        getPurchasesBySupplierUseCase: sl(),
        addSupplierPurchaseUseCase: sl(),
        deleteSupplierPurchaseUseCase: sl(),
      ));
}
