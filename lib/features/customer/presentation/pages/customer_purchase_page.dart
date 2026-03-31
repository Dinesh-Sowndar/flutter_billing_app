import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:billing_app/core/widgets/app_back_button.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../product/data/models/product_model.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/entities/customer_entity.dart';
import 'customer_product_search_page.dart';

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
  bool _scannerPausedByUser = true;
  bool _isFlashOn = false;
  DateTime? _lastStartAttempt;
  Timer? _scannerIdleTimer;
  static const Duration _scannerIdleTimeout = Duration(seconds: 45);

  final Map<String, DateTime> _lastScanTimes = {};
  final List<_CartItem> _cart = [];

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposingScanner = true;
    _cancelScannerIdleTimer();
    _stopScannerSafe();
    _scanner.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_scannerPausedByUser) {
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
    _markScannerActive();
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

  Future<void> _scanFromAppBar() async {
    final barcode = await context.push<String>('/scanner');
    if (!mounted || barcode == null || barcode.isEmpty) return;
    _addProductByBarcode(barcode);
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

  void _applyInlineQuantityAtIndex(int cartIdx, String rawValue) {
    final qty = double.tryParse(rawValue.trim());
    if (qty == null) return;
    setState(() {
      if (qty <= 0) {
        _cart.removeAt(cartIdx);
      } else {
        _cart[cartIdx].quantity = qty;
      }
    });
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

    // Always read balance from Hive directly so it's never stale
    final freshModel = HiveDatabase.customerBox.get(widget.customer.id);
    final freshBalance = freshModel?.balance ?? widget.customer.balance;

    billingBloc.add(SetCustomerEvent(
      customerId: widget.customer.id,
      customerName: widget.customer.name,
      customerDue: freshBalance,
    ));
    for (final item in _cart) {
      billingBloc.add(AddProductToCartEvent(item.product));
      if ((item.quantity - 1.0).abs() > 0.0001) {
        billingBloc.add(UpdateQuantityEvent(item.product.id, item.quantity));
      }
    }

    await context.push('/checkout');
    if (mounted && !_scannerPausedByUser) {
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

    _cancelScannerIdleTimer();
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
          _startScannerIdleTimer();
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
        _startScannerIdleTimer();
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
    _cancelScannerIdleTimer();
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
    _cancelScannerIdleTimer();
    await _recreateScannerController();
    if (!mounted) return;
    setState(() {
      _scannerPausedByUser = false;
      _cameraErrorMessage = null;
    });
    await _startScannerSafe();
  }

  void _startScannerIdleTimer() {
    _cancelScannerIdleTimer();
    _scannerIdleTimer = Timer(_scannerIdleTimeout, () {
      if (!mounted || _scannerPausedByUser || !_scannerRunning) return;
      setState(() {
        _scannerPausedByUser = true;
        _scannerRunning = false;
      });
      _stopScannerSafe();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanner auto-paused due to inactivity'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  void _cancelScannerIdleTimer() {
    _scannerIdleTimer?.cancel();
    _scannerIdleTimer = null;
  }

  void _markScannerActive() {
    if (!_scannerPausedByUser && _scannerRunning) {
      _startScannerIdleTimer();
    }
  }

  // â”€â”€â”€ Build UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = keyboardInset > 0;

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
        leading: AppBackButton(onPressed: () => context.pop()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: _scanFromAppBar,
              tooltip: 'Scan barcode',
              icon: const Icon(Icons.qr_code_scanner_rounded,
                  color: Color(0xFF0F172A), size: 22),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
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
              Offstage(
                offstage: isKeyboardOpen,
                child: _buildCompactScannerPanel(),
              ),
              SizedBox(height: isKeyboardOpen ? 4 : 0),
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
          if (_cart.isNotEmpty && keyboardInset == 0)
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            width: 42,
            height: 42,
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
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Billing to:",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  widget.customer.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_cart.length} Unit(s)',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 11,
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
                Icon(Icons.shopping_cart_rounded, size: 18),
                SizedBox(width: 8),
                Text('Current Order'),
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

  Widget _buildCompactScannerPanel() {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isSmallScreen = screenHeight < 720;
    final scannerViewportHeight = isSmallScreen ? 130.0 : 140.0;
    final scanFrameWidth = isSmallScreen ? 150.0 : 175.0;
    final scanFrameHeight = isSmallScreen ? 72.0 : 84.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Scanner',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: !_scannerPausedByUser
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  !_scannerPausedByUser ? 'Live' : 'Paused',
                  style: TextStyle(
                    color: !_scannerPausedByUser
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: scannerViewportHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!_scannerPausedByUser)
                    MobileScanner(
                      key: ValueKey('customer-scan-$_scannerWidgetVersion'),
                      controller: _scanner,
                      onDetect: _onDetect,
                      errorBuilder: (context, error, child) {
                        final isPermError = error.errorCode ==
                            MobileScannerErrorCode.permissionDenied;
                        return _buildScannerErrorState(
                          isPermissionError: isPermError,
                          errorMessage: _cameraErrorMessage ?? error.toString(),
                        );
                      },
                    )
                  else
                    _buildPausedScannerState(),
                  if (!_scannerPausedByUser)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.18),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.12),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  if (!_scannerPausedByUser)
                    Center(
                      child: Container(
                        width: scanFrameWidth,
                        height: scanFrameHeight,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  if (!_scannerPausedByUser)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Column(
                        children: [
                          _buildScannerOverlayIconButton(
                            icon: _isFlashOn
                                ? Icons.flashlight_off_rounded
                                : Icons.flashlight_on_rounded,
                            isActive: _isFlashOn,
                            onPressed: () {
                              setState(() => _isFlashOn = !_isFlashOn);
                              _scanner.toggleTorch();
                              _markScannerActive();
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildScannerOverlayIconButton(
                            icon: Icons.videocam_off_rounded,
                            onPressed: _toggleScannerPause,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Point the camera at a barcode to add items instantly.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlayIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryColor
                  : Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  // ─── Floating Checkout Bar ──────────────────────────────────────────────────
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs ${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
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
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Row(
            children: [
              const Text(
                'Current Order',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Text(
                '${_cart.length} item(s)',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _cart.isEmpty
              ? const Center(
                  child: Text(
                    'No items in current order.\nAdd from Add Manual tab or scan above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 135;
        final iconPad = compact ? 10.0 : 12.0;
        final iconSize = compact ? 22.0 : 26.0;
        final gap = compact ? 8.0 : 10.0;
        final buttonTextSize = compact ? 11.5 : 12.5;
        final buttonIconSize = compact ? 14.0 : 16.0;
        final buttonHPad = compact ? 10.0 : 12.0;
        final buttonVPad = compact ? 6.0 : 8.0;

        return Container(
          color: const Color(0xFF0F172A).withValues(alpha: 0.9),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(iconPad),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.videocam_off_rounded,
                      color: Colors.white, size: iconSize),
                ),
                SizedBox(height: gap),
                ElevatedButton.icon(
                  onPressed: _resumeScannerFromPanel,
                  icon: Icon(Icons.play_arrow_rounded, size: buttonIconSize),
                  label: Text(
                    'Resume Scanner',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: buttonTextSize,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: buttonHPad,
                      vertical: buttonVPad,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Products Tab Builder ────────────────────────────────────────────────────
  Widget _buildProductsTab() {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      children: [
        // Header w/ View All
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton.icon(
                onPressed: _openProductSearchPage,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        // Product list
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: HiveDatabase.productBox.listenable(),
            builder: (context, box, _) {
              final allProducts = box.values.cast<ProductModel>().toList();
              if (allProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
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
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  keyboardInset +
                      (_cart.isNotEmpty && keyboardInset == 0 ? 100 : 20),
                ),
                itemCount: allProducts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final product = allProducts[i];
                  final cartIdx =
                      _cart.indexWhere((c) => c.product.id == product.id);
                  return _buildProductListItem(product, cartIdx);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Navigates to the full-screen customer product search page.
  Future<void> _openProductSearchPage() async {
    final snapshot = <String, double>{
      for (final item in _cart) item.product.id: item.quantity,
    };

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerProductSearchPage(
          cartSnapshot: snapshot,
          onAddProduct: (product) {
            _addToCart(product);
          },
          onRemoveProduct: (productId) {
            setState(() {
              _cart.removeWhere((c) => c.product.id == productId);
            });
          },
          onUpdateQuantity: (productId, qty) {
            setState(() {
              final idx = _cart.indexWhere((c) => c.product.id == productId);
              if (idx >= 0) _cart[idx].quantity = qty;
            });
          },
        ),
      ),
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
              onTap: () {
                _addToCart(product);
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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        keyboardInset + (_cart.isNotEmpty && keyboardInset == 0 ? 100 : 20),
      ),
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
                  }),
              SizedBox(
                width: 56,
                child: _isWeightedUnit(product)
                    ? TextFormField(
                        key: ValueKey('${product.id}-$qty'),
                        initialValue: _formatQty(qty),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onFieldSubmitted: (value) {
                          _applyInlineQuantityAtIndex(cartIdx, value);
                        },
                      )
                    : Text(
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
                  }),
            ],
          ),
        ),
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
