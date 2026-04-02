import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'config/routes/app_routes.dart';
import 'core/data/hive_database.dart';
import 'core/service_locator.dart' as di;
import 'core/services/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';
import 'features/billing/presentation/bloc/sales_bloc.dart';
import 'features/customer/presentation/bloc/customer_bloc.dart';
import 'features/customer/presentation/bloc/customer_event.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve the native splash until we finish initializing.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await HiveDatabase.init();
  await di.init();

  // Start SyncService so offline->online transitions trigger Firestore sync.
  await di.sl<SyncService>().initialize();

  // Initialization done - remove the splash.
  FlutterNativeSplash.remove();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    di.sl<SyncService>().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(
          value: di.sl<AuthBloc>(),
        ),
        BlocProvider<ProductBloc>(
          create: (context) {
            final bloc = di.sl<ProductBloc>()..add(LoadProducts());
            // Reload products automatically after a sync completes.
            di.sl<SyncService>().onSyncComplete.stream.listen((_) {
              if (!bloc.isClosed) bloc.add(LoadProducts());
            });
            return bloc;
          },
        ),
        BlocProvider<CustomerBloc>(
          create: (context) {
            final bloc = di.sl<CustomerBloc>()..add(LoadCustomersEvent());
            di.sl<SyncService>().onSyncComplete.stream.listen((_) {
              if (!bloc.isClosed) bloc.add(LoadCustomersEvent());
            });
            return bloc;
          },
        ),
        BlocProvider<ShopBloc>(
          create: (context) {
            final bloc = di.sl<ShopBloc>()..add(LoadShopEvent());
            di.sl<SyncService>().onSyncComplete.stream.listen((_) {
              if (!bloc.isClosed) bloc.add(LoadShopEvent());
            });
            return bloc;
          },
        ),
        BlocProvider<BillingBloc>(
            create: (context) => BillingBloc(
                  getProductByBarcodeUseCase: di.sl(),
                  updateProductUseCase: di.sl(),
                  billingRepository: di.sl(),
                  customerRepository: di.sl(),
                )),
        BlocProvider<PrinterBloc>(
            create: (context) => di.sl<PrinterBloc>()..add(InitPrinterEvent())),
        BlocProvider<SalesBloc>(create: (context) {
          final bloc = di.sl<SalesBloc>()..add(LoadSalesEvent());
          di.sl<SyncService>().onSyncComplete.stream.listen((_) {
            if (!bloc.isClosed) bloc.add(LoadSalesEvent());
          });
          return bloc;
        }),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp.router(
            title: 'QuickReceipt',
            theme: AppTheme.lightTheme,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
