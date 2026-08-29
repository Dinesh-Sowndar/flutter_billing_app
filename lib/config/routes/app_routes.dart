import 'package:go_router/go_router.dart';

import '../../features/billing/presentation/pages/home_page.dart';
import '../../features/billing/presentation/pages/manual_pos_page.dart';
import '../../features/billing/presentation/pages/scanner_page.dart';
import '../../features/billing/presentation/pages/checkout_page.dart';

import '../../features/product/presentation/pages/product_list_page.dart';
import '../../features/product/presentation/pages/add_product_page.dart';
import '../../features/product/presentation/pages/edit_product_page.dart';

import '../../features/shop/presentation/pages/shop_details_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

import '../../features/product/domain/entities/product.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),

      routes: [
        GoRoute(
          path: 'scanner',
          builder: (context, state) {
            return const ScannerPage();
          },
        ),

        GoRoute(
          path: 'manual-pos',
          builder: (context, state) {
            return const ManualPosPage();
          },
        ),

        GoRoute(
          path: 'checkout',
          builder: (context, state) {
            return const CheckoutPage();
          },
        ),
      ],
    ),

    GoRoute(
      path: '/settings',
      builder: (context, state) {
        return const SettingsPage();
      },
    ),

    GoRoute(
      path: '/products',
      builder: (context, state) {
        return const ProductListPage();
      },
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) {
            return const AddProductPage();
          },
        ),

        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final product = state.extra as Product?;

            if (product == null) {
              return const ProductListPage();
            }

            return EditProductPage(
              product: product,
            );
          },
        ),
      ],
    ),

    GoRoute(
      path: '/shop',
      builder: (context, state) {
        return const ShopDetailsPage();
      },
    ),
  ],
);
