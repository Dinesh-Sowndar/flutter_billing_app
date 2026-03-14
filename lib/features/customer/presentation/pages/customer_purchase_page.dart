import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/data/hive_database.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../product/data/models/product_model.dart';
import '../../domain/entities/customer_entity.dart';

class _CartItem {
  final ProductModel product;
  int quantity;
  _CartItem({required this.product, required this.quantity});
  double get total => product.price * quantity;
}

class CustomerPurchasePage extends StatefulWidget {
  final CustomerEntity customer;
  const CustomerPurchasePage({super.key, required this.customer});

  @override
  State<CustomerPurchasePage> createState() => _CustomerPurchasePageState();
}

class _CustomerPurchasePageState extends State<CustomerPurchasePage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  final MobileScannerController _scanner = MobileScannerController(
    autoStart: true,
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );

  final Map<String, DateTime> _lastScanTimes = {};
  final List<_CartItem> _cart = [];
  String _productSearch = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Pause scanner when switching to Products tab
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _scanner.stop();
      } else if (_tabController.index == 0) {
        _scanner.start();
      }
    });
  }

  @override
  void dispose() {
    _scanner.dispose();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Scanner helpers ─────────────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) async {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final now = DateTime.now();
      final last = _lastScanTimes[raw];
      if (last != null && now.difference(last).inSeconds < 2) continue;
      _lastScanTimes[raw] = now;
      final canVibrate = await Vibrate.canVibrate;
      if (canVibrate) Vibrate.feedback(FeedbackType.light);
      _addProductByBarcode(raw);
      break;
    }
  }

  void _addProductByBarcode(String barcode) {
    final product = HiveDatabase.productBox.values
        .cast<ProductModel?>()
        .firstWhere((p) => p?.barcode == barcode, orElse: () => null);
    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No product found for barcode: $barcode'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return;
    }
    _addToCart(product);
  }

  void _addToCart(ProductModel product) {
    setState(() {
      final existing = _cart.where((c) => c.product.id == product.id);
      if (existing.isNotEmpty) {
        existing.first.quantity++;
      } else {
        _cart.add(_CartItem(product: product, quantity: 1));
      }
    });
  }

  double get _total => _cart.fold(0, (sum, item) => sum + item.total);

  // ─── Checkout ─────────────────────────────────────────────────────────────
  Future<void> _goToCheckout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cart is empty — add at least one product'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    _scanner.stop();

    final billingBloc = context.read<BillingBloc>();
    billingBloc.add(ClearCartEvent());
    billingBloc.add(SetCustomerEvent(
      customerId: widget.customer.id,
      customerName: widget.customer.name,
    ));
    for (final item in _cart) {
      billingBloc.add(AddProductToCartEvent(item.product));
      if (item.quantity > 1) {
        billingBloc.add(UpdateQuantityEvent(item.product.id, item.quantity));
      }
    }

    await context.push('/checkout');
    if (mounted && _tabController.index == 0) {
      _scanner.start();
    }
  }

  // ─── Corner brackets (same style as ScannerPage) ─────────────────────────
  Widget _buildCorner(Alignment alignment) {
    const color = Color(0xFF10B981);
    const strokeW = 6.0;
    const size = 28.0;
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft ||
                    alignment == Alignment.topRight)
                ? const BorderSide(color: color, width: strokeW)
                : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft ||
                    alignment == Alignment.bottomRight)
                ? const BorderSide(color: color, width: strokeW)
                : BorderSide.none,
            left: (alignment == Alignment.topLeft ||
                    alignment == Alignment.bottomLeft)
                ? const BorderSide(color: color, width: strokeW)
                : BorderSide.none,
            right: (alignment == Alignment.topRight ||
                    alignment == Alignment.bottomRight)
                ? const BorderSide(color: color, width: strokeW)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: alignment == Alignment.topLeft
                ? const Radius.circular(8)
                : Radius.zero,
            topRight: alignment == Alignment.topRight
                ? const Radius.circular(8)
                : Radius.zero,
            bottomLeft: alignment == Alignment.bottomLeft
                ? const Radius.circular(8)
                : Radius.zero,
            bottomRight: alignment == Alignment.bottomRight
                ? const Radius.circular(8)
                : Radius.zero,
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Items',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text(widget.customer.name,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF10B981))),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () => _scanner.toggleTorch(),
            color: const Color(0xFF64748B),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: const Color(0xFF6C63FF),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner_rounded, size: 20), text: 'Scan'),
            Tab(icon: Icon(Icons.list_alt_rounded, size: 20), text: 'Products'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ScanTab(
                  scanner: _scanner,
                  cart: _cart,
                  total: _total,
                  onDetect: _onDetect,
                  buildCorner: _buildCorner,
                  onQtyChange: (i, delta) => setState(() {
                    final newQty = _cart[i].quantity + delta;
                    if (newQty <= 0) {
                      _cart.removeAt(i);
                    } else {
                      _cart[i].quantity = newQty;
                    }
                  }),
                ),
                _ProductsTab(
                  search: _productSearch,
                  searchCtrl: _searchCtrl,
                  cart: _cart,
                  onSearchChanged: (v) =>
                      setState(() => _productSearch = v),
                  onAdd: _addToCart,
                  onQtyChange: (i, delta) => setState(() {
                    final newQty = _cart[i].quantity + delta;
                    if (newQty <= 0) {
                      _cart.removeAt(i);
                    } else {
                      _cart[i].quantity = newQty;
                    }
                  }),
                ),
              ],
            ),
          ),

          // ─── Bottom bar ───
          if (_cart.isNotEmpty)
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500)),
                      Text(
                        '₹${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Items badge
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_cart.fold(0, (s, i) => s + i.quantity)} item(s)',
                      style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _goToCheckout,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('Review Items',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Scan Tab ────────────────────────────────────────────────────────────────
class _ScanTab extends StatelessWidget {
  final MobileScannerController scanner;
  final List<_CartItem> cart;
  final double total;
  final Function(BarcodeCapture) onDetect;
  final Widget Function(Alignment) buildCorner;
  final Function(int, int) onQtyChange;

  const _ScanTab({
    required this.scanner,
    required this.cart,
    required this.total,
    required this.onDetect,
    required this.buildCorner,
    required this.onQtyChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Camera box
        Container(
          color: Colors.black,
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(controller: scanner, onDetect: onDetect),
              Container(color: Colors.black.withValues(alpha: 0.45)),
              Center(
                child: Container(
                  width: 200,
                  height: 170,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(children: [
                    buildCorner(Alignment.topLeft),
                    buildCorner(Alignment.topRight),
                    buildCorner(Alignment.bottomLeft),
                    buildCorner(Alignment.bottomRight),
                  ]),
                ),
              ),
              const Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Text('Align barcode within the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),

        // Scanned items
        Expanded(
          child: cart.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded,
                          size: 52, color: Color(0xFFE2E8F0)),
                      SizedBox(height: 10),
                      Text('No items scanned yet',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF94A3B8))),
                      SizedBox(height: 4),
                      Text('Or switch to Products tab to add manually',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFCBD5E1))),
                    ],
                  ),
                )
              : _CartList(cart: cart, onQtyChange: onQtyChange),
        ),
      ],
    );
  }
}

// ─── Products Tab ─────────────────────────────────────────────────────────────
class _ProductsTab extends StatelessWidget {
  final String search;
  final TextEditingController searchCtrl;
  final List<_CartItem> cart;
  final Function(String) onSearchChanged;
  final Function(ProductModel) onAdd;
  final Function(int, int) onQtyChange;

  const _ProductsTab({
    required this.search,
    required this.searchCtrl,
    required this.cart,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onQtyChange,
  });

  @override
  Widget build(BuildContext context) {
    final all = HiveDatabase.productBox.values.toList();
    final filtered = search.trim().isEmpty
        ? all
        : all
            .where((p) =>
                p.name.toLowerCase().contains(search.toLowerCase()) ||
                p.barcode.contains(search))
            .toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search products…',
              hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF94A3B8)),
              suffixIcon: search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: Color(0xFF94A3B8)),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Product list
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No products found',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final product = filtered[i];
                    final cartIdx = cart
                        .indexWhere((c) => c.product.id == product.id);
                    final inCart = cartIdx >= 0;
                    final qty = inCart ? cart[cartIdx].quantity : 0;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: inCart
                            ? Border.all(
                                color: const Color(0xFF6C63FF)
                                    .withValues(alpha: 0.4),
                                width: 1.5)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2_outlined,
                                color: Color(0xFF6C63FF), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(
                                    '₹${product.price.toStringAsFixed(2)}  •  Stock: ${product.stock}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (inCart) ...[
                            _qtyBtn(Icons.remove, () {
                              onQtyChange(cartIdx, -1);
                            }),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('$qty',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ),
                            _qtyBtn(Icons.add, () {
                              onQtyChange(cartIdx, 1);
                            }, accent: true),
                          ] else
                            GestureDetector(
                              onTap: () => onAdd(product),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C63FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Add',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static Widget _qtyBtn(IconData icon, VoidCallback onTap,
      {bool accent = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: accent
              ? const Color(0xFF6C63FF).withValues(alpha: 0.1)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: accent
                ? const Color(0xFF6C63FF)
                : const Color(0xFF64748B)),
      ),
    );
  }
}

// ─── Shared cart list ─────────────────────────────────────────────────────────
class _CartList extends StatelessWidget {
  final List<_CartItem> cart;
  final Function(int, int) onQtyChange;
  const _CartList({required this.cart, required this.onQtyChange});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: cart.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final item = cart[i];
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: Color(0xFF6C63FF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.product.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('₹${item.product.price.toStringAsFixed(2)} each',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              _qtyBtn(Icons.remove, () => onQtyChange(i, -1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${item.quantity}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              _qtyBtn(Icons.add, () => onQtyChange(i, 1), accent: true),
              const SizedBox(width: 12),
              Text('₹${item.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E293B))),
            ],
          ),
        );
      },
    );
  }

  static Widget _qtyBtn(IconData icon, VoidCallback onTap,
      {bool accent = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: accent
              ? const Color(0xFF6C63FF).withValues(alpha: 0.1)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 16,
            color: accent
                ? const Color(0xFF6C63FF)
                : const Color(0xFF64748B)),
      ),
    );
  }
}
