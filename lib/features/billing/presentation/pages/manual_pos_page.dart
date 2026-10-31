import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../bloc/billing_bloc.dart';

class ManualPosPage extends StatefulWidget {
  const ManualPosPage({
    super.key,
  });

  @override
  State<ManualPosPage> createState() => _ManualPosPageState();
}

class _ManualPosPageState extends State<ManualPosPage> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchText = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      () {
        setState(() {
          _searchText =
              _searchController.text.trim().toLowerCase();
        });
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الكاشير اليدوي',
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_forward_ios,
            size: 20,
          ),
          onPressed: () {
            context.go('/');
          },
        ),
        actions: [
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              if (state.cartItems.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: 8,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'السلة',
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                      ),
                      onPressed: () {
                        context.push('/checkout');
                      },
                    ),
                    Positioned(
                      top: 5,
                      right: 3,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${state.totalQuantity}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            _buildTopSection(),

            Expanded(
              child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, productState) {
                  if (productState.status ==
                      ProductStatus.loading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (productState.status ==
                          ProductStatus.error &&
                      productState.products.isEmpty) {
                    return _buildErrorState(
                      productState.message,
                    );
                  }

                  final products = _filteredProducts(
                    productState.products,
                  );

                  if (products.isEmpty) {
                    return _buildEmptyProductsState(
                      hasSearch: _searchText.isNotEmpty,
                    );
                  }

                  return _buildProductGrid(
                    products,
                  );
                },
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar:
          BlocBuilder<BillingBloc, BillingState>(
        builder: (context, state) {
          if (state.cartItems.isEmpty) {
            return const SizedBox.shrink();
          }

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                14,
                10,
                14,
                10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.08,
                    ),
                    blurRadius: 15,
                    offset: const Offset(
                      0,
                      -3,
                    ),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${state.totalQuantity} قطعة',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(
                          height: 2,
                        ),
                        Text(
                          '${_formatMoney(state.totalAmount)} DZD',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push('/checkout');
                      },
                      icon: const Icon(
                        Icons.receipt_long,
                      ),
                      label: const Text(
                        'عرض الفاتورة',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختر المنتج',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            'اضغط على أي منتج لإضافته مباشرة إلى السلة',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث عن اسم المنتج أو الباركود',
              prefixIcon: const Icon(
                Icons.search,
              ),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      tooltip: 'مسح',
                      icon: const Icon(
                        Icons.clear,
                      ),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(
    List<Product> products,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        14,
        4,
        14,
        110,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 175,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _ProductCard(
          product: products[index],
          onTap: () {
            _addProduct(
              products[index],
            );
          },
        );
      },
    );
  }

  void _addProduct(
    Product product,
  ) {
    context.read<BillingBloc>().add(
          AddProductToCartEvent(
            product,
          ),
        );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child: Text(
                'تمت إضافة ${product.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(
          milliseconds: 800,
        ),
      ),
    );
  }

  List<Product> _filteredProducts(
    List<Product> products,
  ) {
    if (_searchText.isEmpty) {
      return products;
    }

    return products.where(
      (product) {
        final name =
            product.name.toLowerCase();

        final barcode =
            product.barcode.toLowerCase();

        return name.contains(_searchText) ||
            barcode.contains(_searchText);
      },
    ).toList();
  }

  Widget _buildEmptyProductsState({
    required bool hasSearch,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off
                  : Icons.inventory_2_outlined,
              size: 60,
              color: Colors.grey.shade300,
            ),

            const SizedBox(
              height: 14,
            ),

            Text(
              hasSearch
                  ? 'لم يتم العثور على المنتج'
                  : 'لا توجد منتجات',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              hasSearch
                  ? 'جرّب البحث باسم آخر أو باستخدام الباركود.'
                  : 'أضف منتجات من قسم المنتجات أولاً.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    String? message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red.shade300,
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'تعذر تحميل المنتجات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (message != null) ...[
              const SizedBox(
                height: 8,
              ),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            const SizedBox(
              height: 18,
            ),

            ElevatedButton.icon(
              onPressed: () {
                context.read<ProductBloc>().add(
                      LoadProducts(),
                    );
              },
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'إعادة المحاولة',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMoney(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.035,
                ),
                blurRadius: 8,
                offset: const Offset(
                  0,
                  3,
                ),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor
                          .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 29,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_formatMoney(product.price)} DZD',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color:
                            AppTheme.primaryColor,
                      ),
                    ),
                  ),

                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color:
                          AppTheme.primaryColor,
                      borderRadius:
                          BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMoney(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }
}
