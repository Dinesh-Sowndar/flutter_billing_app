import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

bool didCompleteBootstrapInit = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppBootstrap());
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late Future<void> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _initializeApp();
  }

  static Future<void> _initializeApp() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await HiveDatabase.init();
    await di.init();
    await di.sl<SyncService>().initialize();
    didCompleteBootstrapInit = true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: _StartupErrorScreen(
                onRetry: () {
                  setState(() {
                    _startupFuture = _initializeApp();
                  });
                },
              ),
            );
          }
          return const MyApp();
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF1A1A2E),
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                    Color(0xFF0F3460),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _StartupErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 42),
              const SizedBox(height: 12),
              const Text(
                'Startup failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check internet and try again.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

