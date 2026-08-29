import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'config/routes/app_routes.dart';
import 'core/data/hive_database.dart';
import 'core/service_locator.dart' as di;
import 'core/theme/app_theme.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveDatabase.init();
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProductBloc>(
          create: (context) =>
              di.sl<ProductBloc>()..add(LoadProducts()),
        ),
        BlocProvider<ShopBloc>(
          create: (context) =>
              di.sl<ShopBloc>()..add(LoadShopEvent()),
        ),
        BlocProvider<BillingBloc>(
          create: (context) => BillingBloc(
            getProductByBarcodeUseCase: di.sl(),
          ),
        ),
        // يبقى PrinterBloc موجوداً لأن إعدادات الطابعة
        // قد تكون مستخدمة في صفحة الإعدادات.
        BlocProvider<PrinterBloc>(
          create: (context) =>
              di.sl<PrinterBloc>()..add(InitPrinterEvent()),
        ),
      ],
      child: MaterialApp.router(
        title: 'متجري',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: router,

        // RTL عربي للتطبيق بالكامل.
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
