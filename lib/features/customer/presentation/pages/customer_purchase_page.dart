import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final TabController _tabController;

  late MobileScannerController _scanner;
  int _scannerWidgetVersion = 0;
  bool _isStartingScanner = false;
  bool _isDisposingScanner = false;
  String? _cameraErrorMessage;
  bool _scannerRunning = false;
  bool _scannerPausedByUser = false;
  bool _resumeScheduled = false;
  DateTime? _lastStartAttempt;

  final Map<String, DateTime> _lastScanTimes = {};
  final List<_CartItem> _cart = [];
  String _productSearch = '';
  final _searchCtrl = TextEditingController();

  MobileScannerController _createScannerController() {
    return MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanner = _createScannerController();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScannerSafe();
    });

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 1) {
        _scannerPausedByUser = true;
        _stopScannerSafe();
      } else if (_tabController.index == 0 && !_scannerPausedByUser) {
        _ensureScannerActiveSoon();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposingScanner = true;
    _stopScannerSafe();
    _scanner.dispose();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_tabController.index == 0 && !_scannerPausedByUser) {
          _startScannerSafe();
        }
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopScannerSafe();
        return;
    }
  }

  // â”€â”€â”€ Scanner helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  double _stepForUnit(ProductModel product) => 1.0;

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
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          title: Text(
            'Set Quantity (${product.unit.shortLabel})',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: Color(0xFF0F172A),
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Quantity',
              labelStyle: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
              hintText: 'e.g. 1.25',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                Navigator.pop(context, value);
              },
              child: const Text(
                'Apply',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  double get _total => _cart.fold(0, (sum, item) => sum + item.total);

  void _clearAllCart() {
    if (_cart.isEmpty) return;
    setState(() {
      _cart.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All items cleared'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // â”€â”€â”€ Checkout â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _goToCheckout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Cart is empty - add products first.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        backgroundColor: Colors.orange.shade800,
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
    if (!mounted ||
        _scannerRunning ||
        _isStartingScanner ||
        _isDisposingScanner) {
      return;
    }

    final now = DateTime.now();
    if (_lastStartAttempt != null &&
        now.difference(_lastStartAttempt!) <
            const Duration(milliseconds: 280)) {
      return;
    }
    _lastStartAttempt = now;

    _isStartingScanner = true;
    Object? lastError;
    try {
      try {
        await _scanner.stop();
      } catch (_) {}

      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          await _scanner.start();
          if (mounted) {
            setState(() {
              _scannerRunning = true;
              _cameraErrorMessage = null;
            });
          }
          return;
        } catch (e) {
          lastError = e;
          if (attempt == 1) {
            await _recreateScannerController();
          }
          await Future<void>.delayed(
            Duration(milliseconds: 180 * (attempt + 1)),
          );
        }
      }
    } catch (e) {
      lastError = e;
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
    } finally {
      _isStartingScanner = false;
      if (mounted && !_scannerRunning && lastError != null) {
        setState(() => _cameraErrorMessage = lastError.toString());
      }
    }
  }

  Future<void> _recreateScannerController() async {
    try {
      await _scanner.stop();
    } catch (_) {}
    try {
      await _scanner.dispose();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _scanner = _createScannerController();
      _scannerWidgetVersion++;
    });
  }

  Future<void> _stopScannerSafe() async {
    try {
      await _scanner.stop();
    } catch (_) {
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

  // â”€â”€â”€ Build UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    if (_tabController.index == 0 &&
        !_scannerPausedByUser &&
        !_scannerRunning) {
      _ensureScannerActiveSoon();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBody: true,
      appBar: AppBar(
        title: Text(
          'Sale Entry',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 8,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: Colors.black12,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                color: const Color(0xFF0F172A),
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ),
        actions: [
          if (_cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: InkWell(
                onTap: _clearAllCart,
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.delete_sweep_rounded,
                          size: 18, color: Color(0xFFE11D48)),
                      SizedBox(width: 6),
                      Text(
                        'Clear',
                        style: TextStyle(
                          color: Color(0xFFE11D48),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildCustomerBanner(),
              _buildCustomTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildScanTab(),
                    _buildProductsTab(),
                  ],
                ),
              ),
            ],
          ),
          if (_cart.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildFloatingCheckoutBar(),
            ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Header Widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildCustomerBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.9),
                  AppTheme.primaryColor,
                ],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              widget.customer.name.isNotEmpty
                  ? widget.customer.name[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Billing to:",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  widget.customer.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_cart.length} Unit(s)',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Custom Segmented TabBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildCustomTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner_rounded, size: 18),
                SizedBox(width: 8),
                Text('Scan Item'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_rounded, size: 18),
                SizedBox(width: 8),
                Text('Add Manual'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Floating Checkout Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFloatingCheckoutBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs ${_total.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _goToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                children: [
                  Text('Checkout',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Scan Tab Builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildScanTab() {
    return Column(
      children: [
        // Premium Scanner Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.transparent),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  key: ValueKey('customer-scan-$_scannerWidgetVersion'),
                  controller: _scanner,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    final isPermError = error.errorCode ==
                        MobileScannerErrorCode.permissionDenied;
                    return _buildScannerErrorState(
                        isPermissionError: isPermError,
                        errorMessage: _cameraErrorMessage ?? error.toString());
                  },
                ),
                if (_scannerRunning) ...[
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.5),
                          width: 2),
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.flashlight_on_rounded,
                          color: Colors.white),
                      onPressed: () => _scanner.toggleTorch(),
                      style:
                          IconButton.styleFrom(backgroundColor: Colors.black45),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon:
                          const Icon(Icons.pause_rounded, color: Colors.white),
                      onPressed: _toggleScannerPause,
                      style:
                          IconButton.styleFrom(backgroundColor: Colors.black45),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.filter_center_focus_rounded,
                        color: Colors.white54, size: 100),
                  ),
                ] else
                  _buildPausedScannerState(),
              ],
            ),
          ),
        ),
        // Section Title
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Text("Scanned Items",
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: const Color(0xFF1E293B))),
              const Spacer(),
              if (_cart.isNotEmpty)
                Text('${_cart.length} item(s)',
                    style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        // Cart List View
        Expanded(
          child: _cart.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded,
                          size: 48, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text("Points scanner at product barcode",
                          style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : _buildCartListView(),
        ),
      ],
    );
  }

  Widget _buildScannerErrorState(
      {required bool isPermissionError, required String errorMessage}) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.white, size: 44),
          const SizedBox(height: 12),
          Text(
            isPermissionError
                ? 'Camera permission denied.'
                : 'Unable to open camera.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () async {
              await _recreateScannerController();
              await _startScannerSafe();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry Camera'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPausedScannerState() {
    return Container(
      color: const Color(0xFF0F172A).withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.videocam_off_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _resumeScannerFromPanel,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("Resume Scanner",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white),
            )
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Products Tab Builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildProductsTab() {
    final all = HiveDatabase.productBox.values.toList();
    final filtered = _productSearch.trim().isEmpty
        ? all
        : all
            .where((p) =>
                p.name.toLowerCase().contains(_productSearch.toLowerCase()) ||
                p.barcode.contains(_productSearch))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _productSearch = v),
            style: const TextStyle(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Search products by name or barcode...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
              suffixIcon: _productSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _productSearch = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No products match your search.',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final product = filtered[i];
                    final cartIdx =
                        _cart.indexWhere((c) => c.product.id == product.id);
                    return _buildProductListItem(product, cartIdx);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductListItem(ProductModel product, int cartIdx) {
    final inCart = cartIdx >= 0;
    final qty = inCart ? _cart[cartIdx].quantity : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: inCart
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.grey.shade100,
          width: inCart ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs ${product.price.toStringAsFixed(0)} / ${product.unit.shortLabel} - Stock: ${product.stock}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (inCart)
            _buildQtyControls(cartIdx, product, qty)
          else
            GestureDetector(
              onTap: () async {
                _addToCart(product);
                if (_isWeightedUnit(product)) {
                  final newIdx =
                      _cart.indexWhere((c) => c.product.id == product.id);
                  if (newIdx < 0) return;
                  final q = await _showManualQtyDialog(
                      product, _cart[newIdx].quantity);
                  if (!mounted || q == null) return;
                  setState(() {
                    if (q <= 0) {
                      _cart.removeAt(newIdx);
                    } else {
                      _cart[newIdx].quantity = q;
                    }
                  });
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Add',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Shared Cart List Builder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildCartListView() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: _cart.length,
      itemBuilder: (ctx, i) {
        final item = _cart[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs ${item.product.price.toStringAsFixed(0)} x ${_formatQty(item.quantity)} ${item.product.unit.shortLabel}  =  Rs ${item.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildQtyControls(i, item.product, item.quantity),
            ],
          ),
        );
      },
    );
  }

  // â”€â”€â”€ Quantity Controls Component â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildQtyControls(int cartIdx, ProductModel product, double qty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
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
                onPressed: () {
                  setState(() {
                    final newQty = qty - _stepForUnit(product);
                    if (newQty <= 0) {
                      _cart.removeAt(cartIdx);
                    } else {
                      _cart[cartIdx].quantity = newQty;
                    }
                  });
                }
              ),
              SizedBox(
                width: 48,
                child: Text(
                  _formatQty(qty),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              _circularIconButton(
                icon: Icons.add_rounded,
                color: AppTheme.primaryColor,
                onPressed: () {
                  setState(() {
                    _cart[cartIdx].quantity += _stepForUnit(product);
                  });
                }
              ),
            ],
          ),
        ),
        if (_isWeightedUnit(product)) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: () async {
              final q = await _showManualQtyDialog(product, qty);
              if (!mounted || q == null) return;
              setState(() {
                if (q <= 0) {
                  _cart.removeAt(cartIdx);
                } else {
                  _cart[cartIdx].quantity = q;
                }
              });
            },
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Edit qty',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _circularIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
