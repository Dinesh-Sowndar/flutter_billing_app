import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../product/data/models/product_model.dart';
import '../../../product/domain/entities/product.dart';

/// A product search page for the Customer Sale Entry flow.
/// Communicates back via [onAddProduct] / [onRemoveProduct] / [onUpdateQuantity]
/// so it can work with the local cart maintained by [CustomerPurchasePage].
class CustomerProductSearchPage extends StatefulWidget {
  /// Current cart state: productId → quantity
  final Map<String, double> cartSnapshot;
  final void Function(ProductModel product) onAddProduct;
  final void Function(String productId) onRemoveProduct;
  final void Function(String productId, double qty) onUpdateQuantity;

  const CustomerProductSearchPage({
    super.key,
    required this.cartSnapshot,
    required this.onAddProduct,
    required this.onRemoveProduct,
    required this.onUpdateQuantity,
  });

  @override
  State<CustomerProductSearchPage> createState() =>
      _CustomerProductSearchPageState();
}

class _CustomerProductSearchPageState
    extends State<CustomerProductSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String?> _selectedCategoryId = ValueNotifier(null);

  /// Local mutable cart mirror so UI can update immediately.
  late final Map<String, double> _cart;

  @override
  void initState() {
    super.initState();
    _cart = Map<String, double>.from(widget.cartSnapshot);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _selectedCategoryId.dispose();
    super.dispose();
  }

  bool _isWeightedUnit(QuantityUnit unit) =>
      unit == QuantityUnit.kg || unit == QuantityUnit.liter;

  String _formatQty(double qty) {
    if ((qty - qty.roundToDouble()).abs() < 0.0001) {
      return qty.toStringAsFixed(0);
    }
    var text = qty.toStringAsFixed(2);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  String _unitShortLabel(QuantityUnit unit) {
    switch (unit.index) {
      case 1:
        return 'kg';
      case 2:
        return 'L';
      case 3:
        return 'box';
      default:
        return 'pc';
    }
  }

  void _addProduct(ProductModel product) {
    setState(() {
      _cart[product.id] = (_cart[product.id] ?? 0) + 1;
    });
    widget.onAddProduct(product);
  }

  void _decrement(ProductModel product) {
    final current = _cart[product.id] ?? 0;
    final step = 1.0;
    if (current <= step) {
      setState(() => _cart.remove(product.id));
      widget.onRemoveProduct(product.id);
    } else {
      setState(() => _cart[product.id] = current - step);
      widget.onUpdateQuantity(product.id, current - step);
    }
  }

  void _increment(ProductModel product) {
    final current = _cart[product.id] ?? 0;
    setState(() => _cart[product.id] = current + 1);
    widget.onUpdateQuantity(product.id, current + 1);
  }

  void _applyWeightedQty(ProductModel product, String raw) {
    final qty = double.tryParse(raw.trim());
    if (qty == null) return;
    if (qty <= 0) {
      setState(() => _cart.remove(product.id));
      widget.onRemoveProduct(product.id);
    } else {
      setState(() => _cart[product.id] = qty);
      widget.onUpdateQuantity(product.id, qty);
    }
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
        title: const Text(
          'Search Products',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Color(0xFF0F172A),
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
          // ── Search bar ──────────────────────────────────────────────────
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
                    hintStyle:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
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

          // ── Category Chips ───────────────────────────────────────────────
          ValueListenableBuilder<String?>(
            valueListenable: _selectedCategoryId,
            builder: (context, selectedId, _) {
              return ValueListenableBuilder(
                valueListenable: HiveDatabase.categoryBox.listenable(),
                builder: (context, categoryBox, _) {
                  final categories = categoryBox.values.toList();
                  if (categories.isEmpty) return const SizedBox.shrink();

                  return Container(
                    height: 48,
                    color: Colors.white,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 8),
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: selectedId == null,
                          onSelected: (_) =>
                              _selectedCategoryId.value = null,
                          selectedColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            color: selectedId == null
                                ? Colors.white
                                : AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...categories.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c.name),
                              selected: selectedId == c.id,
                              onSelected: (_) =>
                                  _selectedCategoryId.value = c.id,
                              selectedColor: AppTheme.primaryColor,
                              labelStyle: TextStyle(
                                color: selectedId == c.id
                                    ? Colors.white
                                    : AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // ── Product list ─────────────────────────────────────────────────
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

                        var filtered = selectedId == null
                            ? allProducts
                            : allProducts
                                .where((p) => p.categoryId == selectedId)
                                .toList();

                        if (query.isNotEmpty) {
                          filtered = filtered
                              .where((p) =>
                                  p.name.toLowerCase().contains(query) ||
                                  p.barcode.toLowerCase().contains(query))
                              .toList();
                        }

                        return _buildProductList(
                            filtered.cast<ProductModel>().toList());

                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _cart.isNotEmpty
          ? Builder(
              builder: (context) {
                final itemCount = _cart.length;
                double total = 0;
                for (final entry in _cart.entries) {
                  final product = HiveDatabase.productBox.get(entry.key);
                  if (product != null) {
                    total += product.price * entry.value;
                  }
                }
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        'Done   •   $itemCount ${itemCount == 1 ? 'item' : 'items'}   •   ₹${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shadowColor:
                            AppTheme.primaryColor.withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }

  Widget _buildProductList(List<ProductModel> filtered) {
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
            const Text(
              'No products found',
              style: TextStyle(
                  color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final product = filtered[index];
            final qty = _cart[product.id] ?? 0;
            final inCart = qty > 0;
            final weighted = _isWeightedUnit(product.unit);

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
                        Text(
                          product.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                            onPressed: () => _decrement(product),
                          ),
                          SizedBox(
                            width: weighted ? 56 : 42,
                            child: weighted
                                ? TextFormField(
                                    key: ValueKey(
                                        '${product.id}-$qty'),
                                    initialValue: _formatQty(qty),
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
                                        _applyWeightedQty(product, v),
                                  )
                                : Text(
                                    _formatQty(qty),
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
                            onPressed: () => _increment(product),
                          ),
                        ],
                      ),
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
