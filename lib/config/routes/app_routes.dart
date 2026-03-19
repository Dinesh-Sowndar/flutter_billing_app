import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/billing/presentation/pages/home_page.dart';
import '../../features/product/presentation/pages/product_list_page.dart';
import '../../features/product/presentation/pages/add_product_page.dart';
import '../../features/product/presentation/pages/edit_product_page.dart';
import '../../features/shop/presentation/pages/shop_details_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/billing/presentation/pages/scanner_page.dart';
import '../../features/billing/presentation/pages/checkout_page.dart';
import '../../features/product/domain/entities/product.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/billing/presentation/pages/transactions_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/customer/presentation/pages/customer_list_page.dart';
import '../../features/customer/presentation/pages/add_customer_page.dart';
import '../../features/customer/presentation/pages/customer_purchase_page.dart';
import '../../features/customer/presentation/pages/customer_detail_page.dart';
import '../../features/customer/domain/entities/customer_entity.dart';
import '../../core/data/hive_database.dart';
import '../../core/service_locator.dart' as di;
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import 'go_router_refresh_stream.dart';

final router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final isSplash = state.matchedLocation == '/splash';
    final isOnboarding = state.matchedLocation == '/onboarding';
    final authState = di.sl<AuthBloc>().state;
    final isLoggingIn = state.matchedLocation == '/login';
    final isSigningUp = state.matchedLocation == '/signup';
    final isOnboardingCompleted = HiveDatabase.settingsBox
        .get('onboarding_completed', defaultValue: false) as bool;

    // Don't redirect the splash screen.
    if (isSplash) return null;

    if (!isOnboardingCompleted) {
      return isOnboarding ? null : '/onboarding';
    }

    if (isOnboarding) {
      return '/login';
    }

    // While Firebase is still resolving the session or an action is in flight,
    // don't redirect — let the UI show its own loader.
    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading) {
      return null;
    }

    if (authState.status == AuthStatus.unauthenticated ||
        authState.status == AuthStatus.error) {
      if (!isLoggingIn && !isSigningUp) return '/login';
    } else if (authState.status == AuthStatus.authenticated) {
      if (isLoggingIn || isSigningUp) {
        return '/';
      }
    }

    return null;
  },
  refreshListenable: GoRouterRefreshStream(di.sl<AuthBloc>().stream),
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          path: 'scanner',
          builder: (context, state) => const ScannerPage(),
        ),
        GoRoute(
          path: 'checkout',
          builder: (context, state) => const CheckoutPage(),
        ),
        GoRoute(
          path: 'transactions',
          builder: (context, state) => const TransactionsPage(),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductListPage(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddProductPage(),
        ),
        GoRoute(
          path: 'edit/:id',
          builder: (context, state) {
            final product = state.extra as Product?;
            if (product == null) {
              // If we land here without extra (e.g. deep link), go back to products for now.
              return const ProductListPage();
            }
            return EditProductPage(product: product);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/shop',
      builder: (context, state) => const ShopDetailsPage(),
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomerListPage(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddCustomerPage(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final customer = state.extra as CustomerEntity?;
            if (customer == null) return const SizedBox.shrink();
            return CustomerDetailPage(customer: customer);
          },
          routes: [
            GoRoute(
              path: 'purchase',
              builder: (context, state) {
                final customer = state.extra as CustomerEntity?;
                if (customer == null) return const SizedBox.shrink();
                return CustomerPurchasePage(customer: customer);
              },
            ),
          ],
        ),
      ],
    ),
  ],
);
