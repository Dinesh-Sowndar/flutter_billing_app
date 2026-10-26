import 'dart:io';

import 'package:billing_app/features/orders/data/repositories/local_order_repository.dart';
import 'package:billing_app/features/orders/domain/entities/restaurant_order.dart';
import 'package:billing_app/features/orders/presentation/pages/restaurant_home_page.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';
import 'package:billing_app/features/product/data/repositories/product_repository_impl.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import 'package:billing_app/features/product/presentation/bloc/product_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('restaurant-demo-');
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(ProductModelAdapter());
    await Hive.openBox<ProductModel>('products');
    await Hive.openBox('settings');
    await Hive.openBox('restaurant_orders');
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('customer can submit an order for the kitchen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final productRepository = ProductRepositoryImpl();
    final bloc = ProductBloc(
      getProductsUseCase: GetProductsUseCase(productRepository),
      addProductUseCase: AddProductUseCase(productRepository),
      updateProductUseCase: UpdateProductUseCase(productRepository),
      deleteProductUseCase: DeleteProductUseCase(productRepository),
    )..add(LoadProducts());
    addTearDown(bloc.close);
    final orderRepository = LocalOrderRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: RestaurantHomePage(orderRepository: orderRepository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good things, made to order.'), findsOneWidget);
    expect(find.textContaining('Sample menu, saved only on this device'),
        findsOneWidget);

    await tester.tap(find.byTooltip('Add Roasted tomato toast to order'));
    await tester.pumpAndSettle();
    expect(find.text('Review 1 item'), findsOneWidget);

    await tester.tap(find.text('Review 1 item'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('checkout-customer-name')), 'Sam');
    await tester.enterText(find.byKey(const ValueKey('checkout-requirements')),
        'Please leave off the herbs');
    await tester.tap(find.text('Save demo order'));
    await tester.pumpAndSettle();

    final savedOrders = await orderRepository.getOrders();
    expect(savedOrders, hasLength(1));
    expect(savedOrders.single.customerName, 'Sam');
    expect(savedOrders.single.requirements, 'Please leave off the herbs');
    expect(savedOrders.single.items.single.quantity, 1);
    expect(savedOrders.single.status, OrderStatus.received);

    await tester.tap(find.byTooltip('Open kitchen orders'));
    await tester.pumpAndSettle();
    expect(find.text('Kitchen orders'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.textContaining('1 × Roasted tomato toast'), findsOneWidget);
    expect(find.textContaining('Please leave off the herbs'), findsOneWidget);

    await tester.tap(find.byTooltip('Change order status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preparing').last);
    await tester.pumpAndSettle();
    expect((await orderRepository.getOrders()).single.status,
        OrderStatus.preparing);

  });
}
