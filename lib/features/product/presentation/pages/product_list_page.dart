import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:billing_app/core/widgets/app_back_button.dart';

import '../../../../core/service_locator.dart' as di;
import '../../../../core/services/sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

enum _InventoryFilter { all, lowStock, outOfStock, pendingSync }

class _InventoryStats {
  final int totalProducts;
  final int totalUnits;
  final int lowStockCount;
  final int outOfStockCount;
  final int pendingSyncCount;
  final double stockValue;

  const _InventoryStats({
    required this.totalProducts,
    required this.totalUnits,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.pendingSyncCount,
    required this.stockValue,
  });
}

class _ProductListPageState extends State<ProductListPage> {
  static const int _lowStockThreshold = 5;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _InventoryFilter _activeFilter = _InventoryFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _scanQR(List<Product> products) async {
    final barcode = await context.push<String>('/scanner');
    if (barcode == null || barcode.isEmpty) return;

    final matchedProduct =
        products.where((p) => p.barcode == barcode).firstOrNull;
    _searchController.text = matchedProduct?.name ?? barcode;
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete Product?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        content: Text(
          'Are you sure you want to delete "${product.name}"?',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 16),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProductBloc>().add(DeleteProduct(product.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context, List<Product> products) {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No inventory items to delete.'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete All Inventory?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        content: Text(
          'This will permanently delete all ${products.length} items from inventory. Continue?',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 16),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final ids = products.map((p) => p.id).toList();
              context.read<ProductBloc>().add(DeleteAllProducts(ids));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete All',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  _InventoryStats _buildStats(List<Product> products) {
    var totalUnits = 0;
    var lowStock = 0;
    var outOfStock = 0;
    var pendingSync = 0;
    var stockValue = 0.0;

    for (final product in products) {
      totalUnits += product.stock;
      stockValue += product.price * product.stock;
      if (product.stock == 0) {
        outOfStock++;
      } else if (product.stock <= _lowStockThreshold) {
        lowStock++;
      }
      if (product.pendingSync) pendingSync++;
    }

    return _InventoryStats(
      totalProducts: products.length,
      totalUnits: totalUnits,
      lowStockCount: lowStock,
      outOfStockCount: outOfStock,
      pendingSyncCount: pendingSync,
      stockValue: stockValue,
    );
  }

  List<Product> _applyFilters(List<Product> products) {
    return products.where((product) {
      final matchesSearch = _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery) ||
          product.barcode.toLowerCase().contains(_searchQuery);

      final matchesStockFilter = switch (_activeFilter) {
        _InventoryFilter.all => true,
        _InventoryFilter.lowStock =>
          product.stock > 0 && product.stock <= _lowStockThreshold,
        _InventoryFilter.outOfStock => product.stock == 0,
        _InventoryFilter.pendingSync => product.pendingSync,
      };

      return matchesSearch && matchesStockFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = di.sl<SyncService>().isOnline;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 8,
        leading: AppBackButton(onPressed: () => context.pop(), leftPadding: 16),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Inventory',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Track stock health and sync status',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF15803D).withValues(alpha: 0.1)
                    : const Color(0xFF64748B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOnline
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    color: isOnline
                        ? const Color(0xFF15803D)
                        : const Color(0xFF64748B),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: isOnline
                          ? const Color(0xFF15803D)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  tooltip: 'Delete all inventory items',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                  padding: EdgeInsets.zero,
                  onPressed: state.status == ProductStatus.loading
                      ? null
                      : () => _confirmDeleteAll(context, state.products),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ProductBloc, ProductState>(
        listener: (context, state) {
          if (state.status == ProductStatus.success && state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message!),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            );
          } else if (state.status == ProductStatus.error &&
              state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message!),
                backgroundColor: const Color(0xFFE11D48),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            );
          }
        },
        builder: (context, state) {
          final stats = _buildStats(state.products);
          final filteredProducts = _applyFilters(state.products);

          return Column(
            children: [
              _buildSearchBar(state.products),
              if (state.products.isNotEmpty) ...[
                _buildKeyMetrics(stats),
                _buildFilterRow(filteredProducts.length),
              ],
              Expanded(
                child: _buildMainContent(state, filteredProducts),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/products/add'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Add Product',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(List<Product> products) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _searchController,
                textCapitalization: TextCapitalization.words,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search product or barcode...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF94A3B8)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: Color(0xFF94A3B8)),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => _scanQR(products),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.75)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(_InventoryStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Stock Value',
                  value: 'Rs ${stats.stockValue.toStringAsFixed(0)}',
                  subtitle: '${stats.totalUnits} units',
                  icon: Icons.account_balance_wallet_rounded,
                  colors: const [Color(0xFF1E3A8A), Color(0xFF312E81)],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Products',
                  value: '${stats.totalProducts}',
                  subtitle: '${stats.pendingSyncCount} pending sync',
                  icon: Icons.inventory_2_rounded,
                  colors: const [Color(0xFF0F766E), Color(0xFF115E59)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniMetricChip(
                  label: 'Low Stock',
                  value: '${stats.lowStockCount}',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFD97706),
                  background: const Color(0xFFFFF7ED),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetricChip(
                  label: 'Out of Stock',
                  value: '${stats.outOfStockCount}',
                  icon: Icons.remove_shopping_cart_rounded,
                  color: const Color(0xFFDC2626),
                  background: const Color(0xFFFEF2F2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFilterRow(int visibleCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _InventoryFilterChip(
              selected: _activeFilter == _InventoryFilter.all,
              label: 'All',
              onTap: () => setState(() => _activeFilter = _InventoryFilter.all),
            ),
            const SizedBox(width: 8),
            _InventoryFilterChip(
              selected: _activeFilter == _InventoryFilter.lowStock,
              label: 'Low Stock',
              onTap: () =>
                  setState(() => _activeFilter = _InventoryFilter.lowStock),
            ),
            const SizedBox(width: 8),
            _InventoryFilterChip(
              selected: _activeFilter == _InventoryFilter.outOfStock,
              label: 'Out of Stock',
              onTap: () =>
                  setState(() => _activeFilter = _InventoryFilter.outOfStock),
            ),
            const SizedBox(width: 8),
            _InventoryFilterChip(
              selected: _activeFilter == _InventoryFilter.pendingSync,
              label: 'Pending Sync',
              onTap: () =>
                  setState(() => _activeFilter = _InventoryFilter.pendingSync),
            ),
            const SizedBox(width: 12),
            Text(
              '$visibleCount items',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(ProductState state, List<Product> filteredProducts) {
    if (state.status == ProductStatus.loading && state.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.products.isEmpty) {
      if (state.status == ProductStatus.error) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFFE11D48)),
              const SizedBox(height: 16),
              const Text(
                'Failed to load products',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                state.message ?? 'Unknown error',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<ProductBloc>().add(LoadProducts()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
      return _buildEmptyState();
    }

    if (filteredProducts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Color(0xFFCBD5E1)),
            SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF475569),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try another search term or filter.',
              style: TextStyle(
                  color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return _buildProductListItem(context, product);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_rounded,
                size: 64, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your inventory is empty',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.5,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start adding products to your store catalogue by scanning barcodes or adding manually.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductListItem(BuildContext context, Product product) {
    final stockColor = product.stock == 0
        ? const Color(0xFFB91C1C)
        : product.stock <= _lowStockThreshold
            ? const Color(0xFFB45309)
            : const Color(0xFF15803D);

    final stockBackground = product.stock == 0
        ? const Color(0xFFFEE2E2)
        : product.stock <= _lowStockThreshold
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFDCFCE7);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.qr_code_2_rounded,
                            size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.barcode,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs ${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: stockBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${product.stock} ${product.unit.shortLabel}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: stockColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Value: Rs ${(product.stock * product.price).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: product.pendingSync
                      ? Colors.orange.withValues(alpha: 0.12)
                      : Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      product.pendingSync
                          ? Icons.cloud_upload_outlined
                          : Icons.cloud_done_outlined,
                      size: 12,
                      color: product.pendingSync
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      product.pendingSync ? 'Pending Sync' : 'Synced',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: product.pendingSync
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _ActionIconButton(
                icon: Icons.edit_rounded,
                color: AppTheme.primaryColor,
                background: AppTheme.primaryColor.withValues(alpha: 0.1),
                onTap: () => context.push('/products/edit/${product.id}',
                    extra: product),
              ),
              const SizedBox(width: 8),
              _ActionIconButton(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFE11D48),
                background: const Color(0xFFE11D48).withValues(alpha: 0.1),
                onTap: () => _confirmDelete(context, product),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  const _MiniMetricChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryFilterChip extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _InventoryFilterChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
