import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/billing/presentation/bloc/billing_bloc.dart';
import 'package:billing_app/features/billing/domain/entities/cart_item.dart';

class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({super.key});

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String?> _selectedCategoryId = ValueNotifier(null);

  @override
  void dispose() {
    _searchController.dispose();
    _selectedCategoryId.dispose();
    super.dispose();
  }

  /// Returns the short unit label without using extensions (avoids library boundary issues).
  String _unitShortLabel(QuantityUnit unit) {
    switch (unit.index) {
      case 1: return 'kg';
      case 2: return 'L';
      case 3: return 'box';
      case 4: return 'kg+pc';
      default: return 'pc';
    }
  }

  bool _isWeightedUnit(QuantityUnit unit) =>
      unit == QuantityUnit.kg ||
      unit == QuantityUnit.liter ||
      unit == QuantityUnit.pieceWithKg;

  bool _isPieceWithKg(QuantityUnit unit) => unit == QuantityUnit.pieceWithKg;

  String _formatQty(double qty) {
    if ((qty - qty.roundToDouble()).abs() < 0.0001) {
      return qty.toStringAsFixed(0);
    }
    var text = qty.toStringAsFixed(2);
    while (text.endsWith('0')) text = text.substring(0, text.length - 1);
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text;
  }

  void _addProduct(Product product) {
    context.read<BillingBloc>().add(
      AddProductToCartEvent(
        product,
        secondaryQuantity: _isPieceWithKg(product.unit) ? 1.0 : null,
      ),
    );
    Vibrate.canVibrate.then((can) {
      if (can) Vibrate.feedback(FeedbackType.light);
    });
  }

  void _increment(CartItem item) {
    context.read<BillingBloc>().add(
        UpdateQuantityEvent(item.product.id, item.quantity + 1));
    if (_isPieceWithKg(item.product.unit)) {
      context.read<BillingBloc>().add(
            UpdateSecondaryQuantityEvent(
              item.product.id,
              item.secondaryQuantity + 1,
            ),
          );
    }
    Vibrate.canVibrate.then((can) {
      if (can) Vibrate.feedback(FeedbackType.light);
    });
  }

  void _decrement(CartItem item) {
    if (item.quantity > 1) {
      context.read<BillingBloc>().add(
          UpdateQuantityEvent(item.product.id, item.quantity - 1));
      if (_isPieceWithKg(item.product.unit)) {
        context.read<BillingBloc>().add(
              UpdateSecondaryQuantityEvent(
                item.product.id,
                item.secondaryQuantity > 0 ? item.secondaryQuantity - 1 : 0,
              ),
            );
      }
    } else {
      context.read<BillingBloc>().add(
          RemoveProductFromCartEvent(item.product.id));
    }
    Vibrate.canVibrate.then((can) {
      if (can) Vibrate.feedback(FeedbackType.light);
    });
  }

  void _applyWeightedQty(CartItem item, String raw) {
    final qty = double.tryParse(raw.trim());
    if (qty == null) return;
    if (qty <= 0) {
      context.read<BillingBloc>().add(RemoveProductFromCartEvent(item.product.id));
    } else {
      context.read<BillingBloc>().add(UpdateQuantityEvent(item.product.id, qty));
    }
  }

  void _applySecondaryQty(CartItem item, String raw) {
    final qty = double.tryParse(raw.trim());
    if (qty == null) return;
    context.read<BillingBloc>().add(
          UpdateSecondaryQuantityEvent(
            item.product.id,
            qty < 0 ? 0 : qty.roundToDouble(),
          ),
        );
  }

  void _incrementSecondary(CartItem item) {
    context.read<BillingBloc>().add(
          UpdateSecondaryQuantityEvent(
            item.product.id,
            item.secondaryQuantity + 1,
          ),
        );
  }

  void _decrementSecondary(CartItem item) {
    context.read<BillingBloc>().add(
          UpdateSecondaryQuantityEvent(
            item.product.id,
            item.secondaryQuantity > 0 ? item.secondaryQuantity - 1 : 0,
          ),
        );
  }

  Widget _circularIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title:  Text(
          'Search Products',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20.sp,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: Column(
        children: [
          // Search bar below the AppBar in the body
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                return TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search by name or barcode…',
                    hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF94A3B8), size: 20),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: Color(0xFF94A3B8), size: 20),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                );
              },
            ),
          ),

          // Category Chips
          ValueListenableBuilder<String?>(
            valueListenable: _selectedCategoryId,
            builder: (context, selectedId, _) {
              return ValueListenableBuilder(
                valueListenable: HiveDatabase.categoryBox.listenable(),
                builder: (context, categoryBox, _) {
                  final categories = categoryBox.values.toList();
                  if (categories.isEmpty) return const SizedBox.shrink(); // Hide if no categories

                  return Container(
                    height: 48,
                    color: Colors.white,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      children: [
                        ChoiceChip(
                          label:  Text('All',style: TextStyle(fontSize: 12.sp),),
                          selected: selectedId == null,
                          onSelected: (_) => _selectedCategoryId.value = null,
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: selectedId == null ? Colors.white : AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...categories.map((c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(c.name),
                                selected: selectedId == c.id,
                                onSelected: (_) => _selectedCategoryId.value = c.id,
                                selectedColor: AppTheme.primaryColor,
                                labelStyle: TextStyle(
                                  color: selectedId == c.id ? Colors.white : AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // Product list
          Expanded(
            child: ValueListenableBuilder<String?>(
              valueListenable: _selectedCategoryId,
              builder: (context, selectedId, _) {
                return ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, searchVal, _) {
                    final query = searchVal.text.trim().toLowerCase();
                    return ValueListenableBuilder(
                      valueListenable: HiveDatabase.productBox.listenable(),
                      builder: (context, box, _) {
                        final allProducts = box.values.toList();
                        
                        // First filter by category
                        var filtered = selectedId == null
                            ? allProducts
                            : allProducts.where((p) => p.categoryId == selectedId).toList();
                            
                        // Then filter by search query
                        if (query.isNotEmpty) {
                          filtered = filtered
                              .where((p) =>
                                  p.name.toLowerCase().contains(query) ||
                                  p.barcode.toLowerCase().contains(query))
                              .toList();
                        }
                          
                        return _buildProductList(filtered);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BlocBuilder<BillingBloc, BillingState>(
        builder: (context, state) {
          if (state.cartItems.isEmpty) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SizedBox(
              height: 46,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/checkout'),
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: Text(
                  'Review Order   •   ${state.cartItems.length} ${state.cartItems.length == 1 ? 'item' : 'items'}   •   ₹${state.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.35),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductList(List<dynamic> filtered) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.inventory_2_outlined,
                  size: 34, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 12),
            const Text('No products found',
                style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return BlocBuilder<BillingBloc, BillingState>(
      builder: (context, state) {
        final cartByProductId = {
          for (final cartItem in state.cartItems)
            cartItem.product.id: cartItem,
        };

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final productModel = filtered[index];
            final product = productModel.toEntity() as Product;
            final cartItem = cartByProductId[product.id];
            final inCart = cartItem != null;
            final weighted = _isWeightedUnit(product.unit);
            final pieceWithKg = _isPieceWithKg(product.unit);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: inCart ? const Color(0xFFF8FAFC) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: inCart
                    ? Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.35),
                        width: 1.5)
                    : Border.all(color: Colors.grey.shade100, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Product icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                        color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),

                  // Product details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style:  TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.sp,
                                color: const Color(0xFF1E293B))),
                        const SizedBox(height: 3),
                        Text(
                          '₹${product.price.toStringAsFixed(2)}  •  ${_unitShortLabel(product.unit)}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Controls
                  if (inCart)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'KG',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _circularIconButton(
                                icon: Icons.remove_rounded,
                                color: const Color(0xFF64748B),
                                onPressed: () => _decrement(cartItem),
                              ),
                              SizedBox(
                                width: weighted ? 56 : 42,
                                child: weighted
                                    ? TextFormField(
                                        key: ValueKey(
                                          'search-kg-${cartItem.product.id}'),
                                        initialValue:
                                            _formatQty(cartItem.quantity),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                                decimal: true),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A)),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onFieldSubmitted: (v) =>
                                            _applyWeightedQty(cartItem, v),
                                        onChanged: (v) =>
                                          _applyWeightedQty(cartItem, v),
                                      )
                                    : Text(
                                        _formatQty(cartItem.quantity),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A)),
                                      ),
                              ),
                              _circularIconButton(
                                icon: Icons.add_rounded,
                                color: AppTheme.primaryColor,
                                onPressed: () => _increment(cartItem),
                              ),
                            ],
                          ),
                        ),
                        if (pieceWithKg)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'Pieces / Bunch Count',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _circularIconButton(
                                        icon: Icons.remove_rounded,
                                        color: const Color(0xFF64748B),
                                        onPressed: () =>
                                            _decrementSecondary(cartItem),
                                      ),
                                      SizedBox(
                                        width: 56,
                                        child: TextFormField(
                                            key: ValueKey(
                                              'search-sec-${cartItem.product.id}'),
                                          initialValue: cartItem
                                              .secondaryQuantity
                                              .toStringAsFixed(0),
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: Color(0xFF0F172A)),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onFieldSubmitted: (v) =>
                                              _applySecondaryQty(cartItem, v),
                                            onChanged: (v) =>
                                              _applySecondaryQty(cartItem, v),
                                        ),
                                      ),
                                      _circularIconButton(
                                        icon: Icons.add_rounded,
                                        color: AppTheme.primaryColor,
                                        onPressed: () =>
                                            _incrementSecondary(cartItem),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => _addProduct(product),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
