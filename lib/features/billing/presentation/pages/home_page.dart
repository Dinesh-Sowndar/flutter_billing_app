import 'package:billing_app/features/billing/data/models/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:ui';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../billing/presentation/bloc/sales_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/cart_item.dart';
import '../../../product/domain/entities/product.dart';
import '../../../../core/data/hive_database.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _productSearchController =
      TextEditingController();
  String _productSearchQuery = '';

  late MobileScannerController _scannerController;
  int _scannerWidgetVersion = 0;
  bool _isStartingScanner = false;
  bool _isDisposingScanner = false;

  bool _isCameraOn = true;
  bool _scannerRunning = false;
  bool _isFlashOn = false;
  bool _resumeScheduled = false;
  DateTime? _lastResumeAttempt;
  String? _cameraErrorMessage;

  final Map<String, DateTime> _lastScanTimes = {};

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
    _tabController = TabController(length: 2, vsync: this);
    _scannerController = _createScannerController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_resumeScanner());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _resumeScanner();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _pauseScanner();
        return;
    }
  }

  Future<void> _recreateScannerController() async {
    try {
      await _scannerController.stop();
    } catch (_) {}
    try {
      await _scannerController.dispose();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _scannerController = _createScannerController();
      _scannerWidgetVersion++;
      _scannerRunning = false;
    });
  }

  Future<void> _resumeScanner() async {
    if (!mounted ||
        !_isCameraOn ||
        _isDisposingScanner ||
        _isStartingScanner ||
        _scannerRunning) {
      return;
    }

    final route = ModalRoute.of(context);
    if (!(route?.isCurrent ?? false)) return;

    _isStartingScanner = true;
    Object? lastError;
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await _scannerController.start();
          if (!mounted) return;
          setState(() {
            _cameraErrorMessage = null;
            _scannerRunning = true;
          });
          return;
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('already') &&
              (msg.contains('running') || msg.contains('started'))) {
            if (mounted) {
              setState(() {
                _cameraErrorMessage = null;
                _scannerRunning = true;
              });
            }
            return;
          }
          lastError = e;
          await Future<void>.delayed(
              Duration(milliseconds: 180 * (attempt + 1)));
          if (attempt == 1) {
            await _recreateScannerController();
          }
        }
      }

      if (mounted) {
        setState(() {
          _cameraErrorMessage = lastError?.toString();
        });
      }
    } finally {
      _isStartingScanner = false;
    }
  }

  Future<void> _pauseScanner() async {
    if (_isDisposingScanner) return;
    try {
      await _scannerController.stop();
    } catch (_) {
      // Ignore pause failures during rapid navigation/dispose.
    } finally {
      _scannerRunning = false;
    }
  }

  void _ensureScannerActiveSoon() {
    if (_resumeScheduled || !_isCameraOn) return;
    _resumeScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeScheduled = false;
      if (!mounted || !_isCameraOn) return;

      final route = ModalRoute.of(context);
      if (!(route?.isCurrent ?? false)) return;

      final now = DateTime.now();
      if (_lastResumeAttempt != null &&
          now.difference(_lastResumeAttempt!) <
              const Duration(milliseconds: 500)) {
        return;
      }

      _lastResumeAttempt = now;
      unawaited(_resumeScanner());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposingScanner = true;
    unawaited(_pauseScanner());
    unawaited(_scannerController.dispose());
    _tabController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    final now = DateTime.now();

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final rawValue = barcode.rawValue!;

        if (_lastScanTimes.containsKey(rawValue)) {
          final lastScan = _lastScanTimes[rawValue]!;
          if (now.difference(lastScan).inSeconds < 2) {
            continue;
          }
        }

        _lastScanTimes[rawValue] = now;

        final canVibrate = await Vibrate.canVibrate;
        if (canVibrate) {
          Vibrate.feedback(FeedbackType.light);
        }

        if (mounted) {
          context.read<BillingBloc>().add(ScanBarcodeEvent(rawValue));
        }
        break;
      }
    }
  }

  bool _isWeightedUnit(QuantityUnit unit) =>
      unit == QuantityUnit.kg || unit == QuantityUnit.liter;

  double _stepForUnit(QuantityUnit unit) => _isWeightedUnit(unit) ? 0.25 : 1.0;

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

  String _formatQtyWithUnit(double qty, QuantityUnit unit) {
    return '${_formatQty(qty)} ${unit.shortLabel}';
  }

  Future<void> _setManualQuantityForCartItem(CartItem item) async {
    final controller = TextEditingController(text: _formatQty(item.quantity));
    final qty = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set Quantity (${item.product.unit.shortLabel})'),
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
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                Navigator.pop(context, value);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (!mounted || qty == null) return;
    context.read<BillingBloc>().add(UpdateQuantityEvent(item.product.id, qty));
  }

  void _clearAllGuestCart() {
    context.read<BillingBloc>().add(ClearCartEvent());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All added items cleared'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureScannerActiveSoon();

    return Scaffold(
      backgroundColor: Colors.black, // Dark background for scanner
      body: BlocListener<BillingBloc, BillingState>(
        listenWhen: (previous, current) =>
            previous.error != current.error && current.error != null,
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        },
        child: Stack(
          children: [
            // SCANNER VIEW (TOP 45%)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.45,
              child: _buildScannerSection(),
            ),

            // BOTTOM PANEL (BOTTOM 55% + OVERLAP)
            Positioned(
              top: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).padding.top
                  : (MediaQuery.of(context).size.height * 0.45) - 32,
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
      bottomSheet: BlocBuilder<BillingBloc, BillingState>(
        builder: (context, state) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: state.cartItems.isEmpty ? 0 : 100, // Hide button gracefully
            child: Wrap(
              children: [
                if (state.cartItems.isNotEmpty)
                  Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: PrimaryButton(
                      onPressed: () async {
                        await _pauseScanner();
                        await context.push('/checkout');
                        if (_isCameraOn && mounted) await _resumeScanner();
                      },
                      icon: Icons.payments_rounded,
                      label: 'Review Order',
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScannerSection() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isCameraOn)
          MobileScanner(
            key: ValueKey('home-scanner-${_scannerWidgetVersion}'),
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: _buildScannerErrorState,
          )
        else
          _buildCameraOffState(),

        // Focus overlay
        if (_isCameraOn)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
            ),
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: 0, sigmaY: 0), // Just keeping the clip
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Settings / Controls Array
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          right: 16,
          child: Column(
            children: [
              _buildModernIconButton(
                icon: Icons.settings_rounded,
                onPressed: () async {
                  await _pauseScanner();
                  await context.push('/settings');
                  if (_isCameraOn && mounted) await _resumeScanner();
                },
              ),
              const SizedBox(height: 16),
              if (_isCameraOn)
                _buildModernIconButton(
                  icon: _isFlashOn
                      ? Icons.flashlight_off_rounded
                      : Icons.flashlight_on_rounded,
                  isActive: _isFlashOn,
                  onPressed: () {
                    setState(() => _isFlashOn = !_isFlashOn);
                    _scannerController.toggleTorch();
                  },
                ),
              if (_isCameraOn) const SizedBox(height: 16),
              _buildModernIconButton(
                icon: _isCameraOn
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                isActive: !_isCameraOn,
                onPressed: () {
                  setState(() {
                    _isCameraOn = !_isCameraOn;
                  });
                  if (_isCameraOn) {
                    _resumeScanner();
                  } else {
                    _pauseScanner();
                  }
                },
              ),
            ],
          ),
        ),

        // Product list / Shop switch icons (optional left side)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: Column(
            children: [
              _buildModernIconButton(
                icon: Icons.inventory_2_rounded,
                onPressed: () async {
                  await _pauseScanner();
                  await context.push('/products');
                  if (_isCameraOn && mounted) await _resumeScanner();
                },
                color: AppTheme.primaryColor.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              _buildModernIconButton(
                icon: Icons.people_alt_rounded,
                onPressed: () async {
                  await _pauseScanner();
                  await context.push('/customers');
                  if (_isCameraOn && mounted) await _resumeScanner();
                },
                color: const Color(0xFF10B981).withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              _buildModernIconButton(
                icon: Icons.bar_chart_rounded,
                onPressed: () => _showSalesDashboard(context),
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernIconButton(
      {required IconData icon,
      required VoidCallback onPressed,
      bool isActive = false,
      Color? color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color ??
                  (isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraOffState() {
    return Container(
      color: const Color(0xFF0F172A), // Slate 900
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // Slate 800
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 8,
                  )
                ]),
            alignment: Alignment.center,
            child: const Icon(Icons.videocam_off_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 24),
          const Text(
            'Scanner is Paused',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Resume the camera to continue scanning barcodes automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              elevation: 0,
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Resume Scanner',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            onPressed: () {
              setState(() => _isCameraOn = true);
              _resumeScanner();
            },
          )
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, -8),
          )
        ],
      ),
      child: Column(
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1), // Slate 300
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: const Color(0xFF94A3B8),
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'Current Order'),
              Tab(text: 'Inventory'),
            ],
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrderTab(),
                _buildInventoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTab() {
    return Column(
      children: [
        // Header (Current Order)
        BlocBuilder<BillingBloc, BillingState>(
          builder: (context, state) {
            final totalItems =
                state.cartItems.fold<double>(0, (sum, i) => sum + i.quantity);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Order Details',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text('${_formatQty(totalItems)} units scanned',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('TOTAL',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text(
                        '₹${state.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).primaryColor,
                            letterSpacing: -1),
                      ),
                      if (state.cartItems.isNotEmpty)
                        TextButton.icon(
                          onPressed: _clearAllGuestCart,
                          icon: const Icon(
                            Icons.delete_sweep_rounded,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                          label: const Text(
                            'Clear All',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),

        Expanded(
          child: BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              if (state.cartItems.isEmpty) {
                return _buildEmptyCart();
              }

              return ListView.builder(
                padding: const EdgeInsets.only(
                    left: 20, right: 20, top: 12, bottom: 120),
                itemCount: state.cartItems.length,
                itemBuilder: (context, index) {
                  final item = state.cartItems[index];
                  return _buildCartItemCard(context, item);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _productSearchController,
            builder: (context, value, _) {
              return TextField(
                controller: _productSearchController,
                decoration: InputDecoration(
                  hintText: 'Search inventory…',
                  hintStyle:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF94A3B8), size: 20),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: Color(0xFF94A3B8), size: 20),
                          onPressed: () {
                            _productSearchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
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

        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _productSearchController,
            builder: (context, searchVal, _) {
              return ValueListenableBuilder(
                valueListenable: HiveDatabase.productBox.listenable(),
                builder: (context, box, _) {
                  final allProducts = box.values.toList();
                  final query = searchVal.text.trim().toLowerCase();
                  final filtered = query.isEmpty
                      ? allProducts
                      : allProducts
                          .where((p) =>
                              p.name.toLowerCase().contains(query) ||
                              p.barcode.toLowerCase().contains(query))
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('No products found',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return BlocBuilder<BillingBloc, BillingState>(
                        builder: (context, state) {
                          final cartItemIndex = state.cartItems.indexWhere(
                              (item) => item.product.id == product.id);
                          final inCart = cartItemIndex >= 0;
                          final cartItem =
                              inCart ? state.cartItems[cartItemIndex] : null;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: inCart
                                  ? Border.all(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.3),
                                      width: 1)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.inventory_2_outlined,
                                      color: AppTheme.primaryColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(product.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF1E293B))),
                                      Text(
                                          '₹${product.price.toStringAsFixed(2)}  •  Stock: ${product.stock} ${product.unit.shortLabel}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                if (inCart && cartItem != null)
                                  Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _circularIconButton(
                                          icon: Icons.remove_rounded,
                                          onPressed: () {
                                            final step =
                                                _stepForUnit(product.unit);
                                            if (cartItem.quantity > step) {
                                              context.read<BillingBloc>().add(
                                                  UpdateQuantityEvent(
                                                      product.id,
                                                      cartItem.quantity -
                                                          step));
                                            } else {
                                              context.read<BillingBloc>().add(
                                                  RemoveProductFromCartEvent(
                                                      product.id));
                                            }
                                            Vibrate.canVibrate.then((can) {
                                              if (can) {
                                                Vibrate.feedback(
                                                    FeedbackType.light);
                                              }
                                            });
                                          },
                                        ),
                                        SizedBox(
                                          width: 80,
                                          child: Text(
                                            _formatQtyWithUnit(
                                                cartItem.quantity,
                                                product.unit),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        if (_isWeightedUnit(product.unit))
                                          _circularIconButton(
                                            icon: Icons.edit_rounded,
                                            onPressed: () {
                                              final item = state
                                                  .cartItems[cartItemIndex];
                                              _setManualQuantityForCartItem(
                                                  item);
                                            },
                                          ),
                                        _circularIconButton(
                                          icon: Icons.close_rounded,
                                          onPressed: () {
                                            context.read<BillingBloc>().add(
                                                RemoveProductFromCartEvent(
                                                    product.id));
                                          },
                                        ),
                                        _circularIconButton(
                                          icon: Icons.add_rounded,
                                          onPressed: () {
                                            final step =
                                                _stepForUnit(product.unit);
                                            context.read<BillingBloc>().add(
                                                UpdateQuantityEvent(product.id,
                                                    cartItem.quantity + step));
                                            Vibrate.canVibrate.then((can) {
                                              if (can) {
                                                Vibrate.feedback(
                                                    FeedbackType.light);
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: () {
                                      if (_isWeightedUnit(product.unit)) {
                                        final entity = product.toEntity();
                                        context
                                            .read<BillingBloc>()
                                            .add(AddProductToCartEvent(entity));
                                        final newItem = CartItem(
                                            product: entity, quantity: 1);
                                        _setManualQuantityForCartItem(newItem);
                                      } else {
                                        context.read<BillingBloc>().add(
                                            AddProductToCartEvent(
                                                product.toEntity()));
                                      }
                                      final canVibrate = Vibrate.canVibrate;
                                      canVibrate.then((can) {
                                        if (can) {
                                          Vibrate.feedback(FeedbackType.light);
                                        }
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Add',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScannerErrorState(
    BuildContext context,
    MobileScannerException error,
    Widget? child,
  ) {
    if (_scannerRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scannerRunning) {
          setState(() => _scannerRunning = false);
        }
      });
    }

    final isPermissionError =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            isPermissionError
                ? 'Camera permission is required for scanning.'
                : 'Unable to open camera. Please retry.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isPermissionError
                ? () => AppSettings.openAppSettings()
                : () async {
                    await _recreateScannerController();
                    await _resumeScanner();
                  },
            child:
                Text(isPermissionError ? 'Open App Settings' : 'Retry Camera'),
          ),
          if (!isPermissionError && _cameraErrorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _cameraErrorMessage!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9), // Slate 100
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.shopping_cart_checkout_rounded,
                size: 48, color: Color(0xFFCBD5E1)), // Slate 300
          ),
          const SizedBox(height: 24),
          const Text('Cart is empty',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Point the camera at a barcode to add items instantly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF64748B), fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '₹${item.product.price.toStringAsFixed(2)}  •  Stock: ${item.product.stock} ${item.product.unit.shortLabel}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _circularIconButton(
                    icon: Icons.remove_rounded,
                    onPressed: () {
                      final step = _stepForUnit(item.product.unit);
                      if (item.quantity > step) {
                        context.read<BillingBloc>().add(UpdateQuantityEvent(
                            item.product.id, item.quantity - step));
                      } else {
                        context
                            .read<BillingBloc>()
                            .add(RemoveProductFromCartEvent(item.product.id));
                      }
                      Vibrate.canVibrate.then((can) {
                        if (can) {
                          Vibrate.feedback(FeedbackType.light);
                        }
                      });
                    }),
                SizedBox(
                  width: 80,
                  child: Text(
                    _formatQtyWithUnit(item.quantity, item.product.unit),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                if (_isWeightedUnit(item.product.unit))
                  _circularIconButton(
                    icon: Icons.edit_rounded,
                    onPressed: () => _setManualQuantityForCartItem(item),
                  ),
                _circularIconButton(
                  icon: Icons.close_rounded,
                  onPressed: () {
                    context
                        .read<BillingBloc>()
                        .add(RemoveProductFromCartEvent(item.product.id));
                  },
                ),
                _circularIconButton(
                    icon: Icons.add_rounded,
                    onPressed: () {
                      final step = _stepForUnit(item.product.unit);
                      context.read<BillingBloc>().add(UpdateQuantityEvent(
                          item.product.id, item.quantity + step));
                      Vibrate.canVibrate.then((can) {
                        if (can) {
                          Vibrate.feedback(FeedbackType.light);
                        }
                      });
                    }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circularIconButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }

  void _showSalesDashboard(BuildContext context) {
    context.read<SalesBloc>().add(LoadSalesEvent());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSalesDashboardSheet(),
    );
  }

  Widget _buildSalesDashboardSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sales Dashboard',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5)),
                IconButton(
                  onPressed: () => context.pop(),
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            BlocBuilder<SalesBloc, SalesState>(
              builder: (context, state) {
                if (state.status == SalesStatus.loading) {
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ));
                }
                if (state.status == SalesStatus.error) {
                  return Center(
                      child: Text(state.error ?? 'Unknown error',
                          style: const TextStyle(color: Colors.red)));
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _buildSalesCard('Today', state.dailySales,
                                state.dailyPending, AppTheme.primaryColor)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildSalesCard(
                                'This Week',
                                state.weeklySales,
                                state.weeklyPending,
                                const Color(0xFF3B82F6))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _buildSalesCard(
                                'This Month',
                                state.monthlySales,
                                state.monthlyPending,
                                const Color(0xFF8B5CF6))),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Recent Transactions',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    if (state.recentTransactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No transactions yet.',
                            style: TextStyle(color: Color(0xFF64748B))),
                      )
                    else
                      ...state.recentTransactions.take(3).map((t) {
                        final isPaymentOnly =
                            t.items.isEmpty && t.amountPaid > 0;
                        return GestureDetector(
                          onTap: () {
                            _showTransactionDetails(context, t);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.customerName.isNotEmpty
                                          ? t.customerName
                                          : 'Guest',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                        isPaymentOnly
                                            ? 'Due Payment'
                                            : (t.items.length == 1
                                                ? '1 item'
                                                : '${t.items.length} items'),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                            color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')} - ${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}/${t.date.year}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                                Text(
                                    isPaymentOnly
                                        ? '+₹${t.amountPaid.toStringAsFixed(2)}'
                                        : '₹${t.totalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: isPaymentOnly
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF1E293B))),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          // Close bottom sheet and navigate
                          context.pop();
                          context.push('/transactions');
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('View All Transactions',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesCard(
      String title, double amount, double pending, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text('₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: -1)),
          const SizedBox(height: 6),
          Text('Pending: ₹${pending.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444))),
        ],
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, TransactionModel t) {
    final due = (t.totalAmount - t.amountPaid).clamp(0.0, double.infinity);
    final isPaymentOnly = t.items.isEmpty && t.amountPaid > 0;
    final balanceDue =
        isPaymentOnly ? _customerDueAfterTransaction(t) : due.toDouble();
    final totalDueAmount =
        isPaymentOnly ? (balanceDue + t.amountPaid) : t.totalAmount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Transaction Details',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5)),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Date: ${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}/${t.date.year} ${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}',
                  style:
                      const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                ),
                if (t.customerName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Customer: ${t.customerName}',
                    style:
                        const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                  ),
                ],
                const SizedBox(height: 24),
                if (!isPaymentOnly) ...[
                  const Text('Items',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: t.items.length,
                      itemBuilder: (context, index) {
                        final item = t.items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16)),
                                    Text(
                                        '${item.quantity} x ₹${item.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                              Text('₹${item.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  const Text('Payment Entry',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'This transaction records a due payment from customer.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isPaymentOnly ? 'Total Due Amount' : 'Total Amount',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('₹${totalDueAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount Paid',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('₹${t.amountPaid.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Balance Amount',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('₹${balanceDue.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: balanceDue > 0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  double _customerDueAfterTransaction(TransactionModel selectedTx) {
    if (selectedTx.customerId.isEmpty) return 0.0;

    final customerTransactions = HiveDatabase.transactionBox.values
        .where((t) => t.customerId == selectedTx.customerId)
        .toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.id.compareTo(b.id);
      });

    var runningDue = 0.0;
    for (final tx in customerTransactions) {
      final isPaymentOnly = tx.items.isEmpty && tx.amountPaid > 0;

      if (isPaymentOnly) {
        runningDue -= tx.amountPaid;
      } else {
        final paidAtSale = tx.amountPaid.clamp(0.0, tx.totalAmount).toDouble();
        runningDue += (tx.totalAmount - paidAtSale);
      }

      if (tx.id == selectedTx.id) {
        break;
      }
    }

    return runningDue < 0 ? 0.0 : runningDue;
  }
}
