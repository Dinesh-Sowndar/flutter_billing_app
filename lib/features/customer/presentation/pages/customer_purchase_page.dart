import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/data/hive_database.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../product/data/models/product_model.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/entities/customer_entity.dart';

class _CartItem {
  final ProductModel product;
  double quantity;
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
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );
  bool _scannerRunning = false;
  bool _scannerPausedByUser = false;
  bool _resumeScheduled = false;
  DateTime? _lastStartAttempt;

  final Map<String, DateTime> _lastScanTimes = {};
  final List<_CartItem> _cart = [];
  String _productSearch = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScannerSafe();
    });

    // Pause scanner when switching to Products tab.
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 1) {
        // Keep scanner paused when moving away from Scan tab.
        _scannerPausedByUser = true;
        _stopScannerSafe();
      } else if (_tabController.index == 0 && !_scannerPausedByUser) {
        _ensureScannerActiveSoon();
      }
    });
  }

  @override
  void dispose() {
    _stopScannerSafe();
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
        existing.first.quantity += _stepForUnit(product);
      } else {
        _cart.add(_CartItem(product: product, quantity: 1.0));
      }
    });
  }

  bool _isWeightedUnit(ProductModel product) =>
      product.unit == QuantityUnit.kg || product.unit == QuantityUnit.liter;

  double _stepForUnit(ProductModel product) =>
      _isWeightedUnit(product) ? 0.25 : 1.0;

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

  Future<double?> _showManualQtyDialog(
      ProductModel product, double currentQty) {
    final controller = TextEditingController(text: _formatQty(currentQty));
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Quantity (${product.unit.shortLabel})'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.trim()),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  double get _total => _cart.fold(0, (sum, item) => sum + item.total);

  void _clearAllCart() {
    if (_cart.isEmpty) return;
    setState(() {
      _cart.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All added items cleared'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Checkout ─────────────────────────────────────────────────────────────
  Future<void> _goToCheckout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cart is empty — add at least one product'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    await _stopScannerSafe();

    final billingBloc = context.read<BillingBloc>();
    billingBloc.add(ClearCartEvent());
    billingBloc.add(SetCustomerEvent(
      customerId: widget.customer.id,
      customerName: widget.customer.name,
    ));
    for (final item in _cart) {
      billingBloc.add(AddProductToCartEvent(item.product));
      if ((item.quantity - 1.0).abs() > 0.0001) {
        billingBloc.add(UpdateQuantityEvent(item.product.id, item.quantity));
      }
    }

    await context.push('/checkout');
    if (mounted && _tabController.index == 0 && !_scannerPausedByUser) {
      await _startScannerSafe();
    }
  }

  Future<void> _toggleScannerPause() async {
    if (_scannerRunning) {
      await _stopScannerSafe();
      if (mounted) {
        setState(() => _scannerPausedByUser = true);
      }
      return;
    }

    await _startScannerSafe();
    if (mounted) {
      setState(() => _scannerPausedByUser = !_scannerRunning);
    }
  }

  Future<void> _startScannerSafe() async {
    if (!mounted || _scannerRunning) return;

    final now = DateTime.now();
    if (_lastStartAttempt != null &&
        now.difference(_lastStartAttempt!) <
            const Duration(milliseconds: 280)) {
      return;
    }
    _lastStartAttempt = now;

    try {
      // Reset any stale camera session before starting a fresh preview.
      try {
        await _scanner.stop();
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 80));
      await _scanner.start();
      if (mounted) {
        setState(() {
          _scannerRunning = true;
        });
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already') &&
          (msg.contains('running') || msg.contains('started'))) {
        if (mounted) {
          setState(() {
            _scannerRunning = true;
          });
        } else {
          _scannerRunning = true;
        }
        return;
      }

      // Retry once after short delay for camera startup race conditions.
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted || _scannerRunning || _tabController.index != 0) return;
      try {
        await _scanner.start();
        if (mounted) {
          setState(() {
            _scannerRunning = true;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _stopScannerSafe() async {
    try {
      await _scanner.stop();
    } catch (_) {
      // Ignore stop race conditions from rapid tab changes.
    } finally {
      if (mounted) {
        setState(() {
          _scannerRunning = false;
        });
      } else {
        _scannerRunning = false;
      }
    }
  }

  Future<void> _resumeScannerFromPanel() async {
    await _startScannerSafe();
    if (mounted && _scannerRunning) {
      setState(() => _scannerPausedByUser = false);
    }
  }

  void _ensureScannerActiveSoon() {
    if (_resumeScheduled || !mounted || _scannerPausedByUser) return;
    _resumeScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeScheduled = false;
      if (!mounted || _scannerPausedByUser || _tabController.index != 0) return;
      _startScannerSafe();
    });
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
    if (_tabController.index == 0 &&
        !_scannerPausedByUser &&
        !_scannerRunning) {
      _ensureScannerActiveSoon();
    }

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
                style: const TextStyle(fontSize: 12, color: Color(0xFF10B981))),
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
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearAllCart,
              tooltip: 'Clear all items',
              color: const Color(0xFFEF4444),
            ),
          IconButton(
            icon: Icon(
              _scannerRunning
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
            ),
            onPressed:
                _tabController.index == 0 ? () => _toggleScannerPause() : null,
            tooltip: _scannerRunning ? 'Pause Scanner' : 'Resume Scanner',
            color: const Color(0xFF64748B),
          ),
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
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(
                icon: Icon(Icons.qr_code_scanner_rounded, size: 20),
                text: 'Scan'),
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
                  isScannerRunning: _scannerRunning,
                  cart: _cart,
                  total: _total,
                  onDetect: _onDetect,
                  buildCorner: _buildCorner,
                  onResumeScanner: _resumeScannerFromPanel,
                  onQtyChange: (i, delta) => setState(() {
                    final newQty = _cart[i].quantity + delta;
                    if (newQty <= 0) {
                      _cart.removeAt(i);
                    } else {
                      _cart[i].quantity = newQty;
                    }
                  }),
                  onRemove: (i) => setState(() {
                    _cart.removeAt(i);
                  }),
                  onManualQty: (i) async {
                    final current = _cart[i];
                    final qty = await _showManualQtyDialog(
                      current.product,
                      current.quantity,
                    );
                    if (!mounted || qty == null) return;
                    setState(() {
                      if (qty <= 0) {
                        _cart.removeAt(i);
                      } else {
                        _cart[i].quantity = qty;
                      }
                    });
                  },
                  isWeighted: (p) => _isWeightedUnit(p),
                  qtyText: _formatQty,
                ),
                _ProductsTab(
                  search: _productSearch,
                  searchCtrl: _searchCtrl,
                  cart: _cart,
                  onSearchChanged: (v) => setState(() => _productSearch = v),
                  onAdd: (product) async {
                    _addToCart(product);
                    if (_isWeightedUnit(product)) {
                      final index =
                          _cart.indexWhere((c) => c.product.id == product.id);
                      if (index < 0) return;
                      final qty = await _showManualQtyDialog(
                          product, _cart[index].quantity);
                      if (!mounted || qty == null) return;
                      setState(() {
                        if (qty <= 0) {
                          _cart.removeAt(index);
                        } else {
                          _cart[index].quantity = qty;
                        }
                      });
                    }
                  },
                  onQtyChange: (i, delta) => setState(() {
                    final newQty = _cart[i].quantity + delta;
                    if (newQty <= 0) {
                      _cart.removeAt(i);
                    } else {
                      _cart[i].quantity = newQty;
                    }
                  }),
                  onRemove: (i) => setState(() {
                    _cart.removeAt(i);
                  }),
                  onManualQty: (i) async {
                    final current = _cart[i];
                    final qty = await _showManualQtyDialog(
                      current.product,
                      current.quantity,
                    );
                    if (!mounted || qty == null) return;
                    setState(() {
                      if (qty <= 0) {
                        _cart.removeAt(i);
                      } else {
                        _cart[i].quantity = qty;
                      }
                    });
                  },
                  stepForProduct: (p) => _stepForUnit(p),
                  isWeighted: (p) => _isWeightedUnit(p),
                  qtyText: _formatQty,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_formatQty(_cart.fold<double>(0, (s, i) => s + i.quantity))} unit(s)',
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
  final bool isScannerRunning;
  final List<_CartItem> cart;
  final double total;
  final Function(BarcodeCapture) onDetect;
  final Widget Function(Alignment) buildCorner;
  final Future<void> Function() onResumeScanner;
  final Function(int, double) onQtyChange;
  final Function(int) onRemove;
  final Future<void> Function(int) onManualQty;
  final bool Function(ProductModel) isWeighted;
  final String Function(double) qtyText;

  const _ScanTab({
    required this.scanner,
    required this.isScannerRunning,
    required this.cart,
    required this.total,
    required this.onDetect,
    required this.buildCorner,
    required this.onResumeScanner,
    required this.onQtyChange,
    required this.onRemove,
    required this.onManualQty,
    required this.isWeighted,
    required this.qtyText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Camera box
        Container(
          width: double.infinity,
          color: Colors.black,
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(controller: scanner, onDetect: onDetect),
              if (isScannerRunning) ...[
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
              ] else ...[
                _buildPausedScannerState(),
              ],
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
              : _CartList(
                  cart: cart,
                  onQtyChange: onQtyChange,
                  onRemove: onRemove,
                  onManualQty: onManualQty,
                  isWeighted: isWeighted,
                  qtyText: qtyText,
                ),
        ),
      ],
    );
  }

  Widget _buildPausedScannerState() {
    return SizedBox.expand(
      child: Container(
        color: const Color(0xFF0F172A),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.videocam_off_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(height: 12),
            const Text(
              'Scanner is Paused',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap resume to continue scanning.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onResumeScanner,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Resume Scanner',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Products Tab ─────────────────────────────────────────────────────────────
class _ProductsTab extends StatelessWidget {
  final String search;
  final TextEditingController searchCtrl;
  final List<_CartItem> cart;
  final Function(String) onSearchChanged;
  final Future<void> Function(ProductModel) onAdd;
  final Function(int, double) onQtyChange;
  final Function(int) onRemove;
  final Future<void> Function(int) onManualQty;
  final double Function(ProductModel) stepForProduct;
  final bool Function(ProductModel) isWeighted;
  final String Function(double) qtyText;

  const _ProductsTab({
    required this.search,
    required this.searchCtrl,
    required this.cart,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onQtyChange,
    required this.onRemove,
    required this.onManualQty,
    required this.stepForProduct,
    required this.isWeighted,
    required this.qtyText,
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
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
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
                    final cartIdx =
                        cart.indexWhere((c) => c.product.id == product.id);
                    final inCart = cartIdx >= 0;
                    final qty = inCart ? cart[cartIdx].quantity : 0.0;

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
                              onQtyChange(cartIdx, -stepForProduct(product));
                            }),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                  '${qtyText(qty)} ${product.unit.shortLabel}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                            if (isWeighted(product))
                              _qtyBtn(Icons.edit_rounded, () {
                                onManualQty(cartIdx);
                              }),
                            _qtyBtn(Icons.close_rounded, () {
                              onRemove(cartIdx);
                            }),
                            _qtyBtn(Icons.add, () {
                              onQtyChange(cartIdx, stepForProduct(product));
                            }, accent: true),
                          ] else
                            GestureDetector(
                              onTap: () {
                                onAdd(product);
                              },
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
            color: accent ? const Color(0xFF6C63FF) : const Color(0xFF64748B)),
      ),
    );
  }
}

// ─── Shared cart list ─────────────────────────────────────────────────────────
class _CartList extends StatelessWidget {
  final List<_CartItem> cart;
  final Function(int, double) onQtyChange;
  final Function(int) onRemove;
  final Future<void> Function(int) onManualQty;
  final bool Function(ProductModel) isWeighted;
  final String Function(double) qtyText;
  const _CartList({
    required this.cart,
    required this.onQtyChange,
    required this.onRemove,
    required this.onManualQty,
    required this.isWeighted,
    required this.qtyText,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: cart.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final item = cart[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    Text(
                        '₹${item.product.price.toStringAsFixed(2)} per ${item.product.unit.shortLabel}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              _qtyBtn(
                Icons.remove,
                () => onQtyChange(i, isWeighted(item.product) ? -0.25 : -1.0),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                    '${qtyText(item.quantity)} ${item.product.unit.shortLabel}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              if (isWeighted(item.product))
                _qtyBtn(Icons.edit_rounded, () {
                  onManualQty(i);
                }),
              _qtyBtn(Icons.close_rounded, () {
                onRemove(i);
              }),
              _qtyBtn(
                Icons.add,
                () => onQtyChange(i, isWeighted(item.product) ? 0.25 : 1.0),
                accent: true,
              ),
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
            color: accent ? const Color(0xFF6C63FF) : const Color(0xFF64748B)),
      ),
    );
  }
}
