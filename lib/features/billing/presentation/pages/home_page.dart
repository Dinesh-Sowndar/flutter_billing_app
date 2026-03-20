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

  late MobileScannerController _scannerController;
  int _scannerWidgetVersion = 0;
  bool _isStartingScanner = false;
  bool _isDisposingScanner = false;

  bool _isCameraOn = false;
  bool _scannerRunning = false;
  bool _isFlashOn = false;
  bool _resumeScheduled = false;
  DateTime? _lastResumeAttempt;
  String? _cameraErrorMessage;
  Timer? _scannerIdleTimer;
  static const Duration _scannerIdleTimeout = Duration(seconds: 45);

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
          _startScannerIdleTimer();
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
            _startScannerIdleTimer();
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
    _cancelScannerIdleTimer();
    try {
      await _scannerController.stop();
    } catch (_) {
      // Ignore pause failures during rapid navigation/dispose.
    } finally {
      _scannerRunning = false;
    }
  }

  void _startScannerIdleTimer() {
    _cancelScannerIdleTimer();
    _scannerIdleTimer = Timer(_scannerIdleTimeout, () {
      if (!mounted || !_isCameraOn || !_scannerRunning) return;
      setState(() {
        _isCameraOn = false;
        _scannerRunning = false;
      });
      unawaited(_pauseScanner());
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
    if (_isCameraOn && _scannerRunning) {
      _startScannerIdleTimer();
    }
  }

  Future<void> _startScannerFromUserAction() async {
    _cancelScannerIdleTimer();

    if (_scannerRunning) {
      await _pauseScanner();
    }

    await _recreateScannerController();
    if (!mounted) return;

    setState(() {
      _isCameraOn = true;
      _cameraErrorMessage = null;
    });

    await _resumeScanner();
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
    _cancelScannerIdleTimer();
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
        _markScannerActive();
        break;
      }
    }
  }

  bool _isWeightedUnit(QuantityUnit unit) =>
      unit == QuantityUnit.kg || unit == QuantityUnit.liter;

  double _stepForUnit(QuantityUnit unit) => 1.0;

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
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          title: Text(
            'Set Quantity (${item.product.unit.shortLabel})',
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

  void _incrementCartItem(CartItem item) {
    final step = _stepForUnit(item.product.unit);
    context
        .read<BillingBloc>()
        .add(UpdateQuantityEvent(item.product.id, item.quantity + step));

    Vibrate.canVibrate.then((can) {
      if (can) {
        Vibrate.feedback(FeedbackType.light);
      }
    });
  }

  void _decrementCartItem(CartItem item) {
    final step = _stepForUnit(item.product.unit);
    if (item.quantity > step) {
      context
          .read<BillingBloc>()
          .add(UpdateQuantityEvent(item.product.id, item.quantity - step));
    } else {
      context.read<BillingBloc>().add(RemoveProductFromCartEvent(item.product.id));
    }

    Vibrate.canVibrate.then((can) {
      if (can) {
        Vibrate.feedback(FeedbackType.light);
      }
    });
  }

  void _addProductFromInventory(Product product) {
    if (_isWeightedUnit(product.unit)) {
      context.read<BillingBloc>().add(AddProductToCartEvent(product));
      final newItem = CartItem(product: product, quantity: 1);
      unawaited(_setManualQuantityForCartItem(newItem));
    } else {
      context.read<BillingBloc>().add(AddProductToCartEvent(product));
    }

    Vibrate.canVibrate.then((can) {
      if (can) {
        Vibrate.feedback(FeedbackType.light);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureScannerActiveSoon();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA), // Elegant light background
      appBar: AppBar(
        title: const Text(
          'Quick Receipt',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          _buildAppBarAction(
            icon: Icons.bar_chart_rounded,
            tooltip: 'Dashboard',
            iconColor: const Color(0xFF2563EB),
            onPressed: () async {
              await _pauseScanner();
              await context.push('/sales-dashboard');
              if (_isCameraOn && mounted) await _resumeScanner();
            },
          ),
          _buildAppBarAction(
            icon: Icons.inventory_2_rounded,
            tooltip: 'Products',
            iconColor: AppTheme.primaryColor,
            onPressed: () async {
              await _pauseScanner();
              await context.push('/products');
              if (_isCameraOn && mounted) await _resumeScanner();
            },
          ),
          _buildAppBarAction(
            icon: Icons.people_alt_rounded,
            tooltip: 'Customers',
            iconColor: const Color(0xFF10B981),
            onPressed: () async {
              await _pauseScanner();
              await context.push('/customers');
              if (_isCameraOn && mounted) await _resumeScanner();
            },
          ),
          _buildAppBarAction(
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            iconColor: const Color(0xFFF59E0B),
            onPressed: () async {
              await _pauseScanner();
              await context.push('/settings');
              if (_isCameraOn && mounted) await _resumeScanner();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
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
        child: Column(
          children: [
            _buildElegantScannerCard(),
            const SizedBox(height: 14),
            Expanded(child: _buildBottomPanel()),
          ],
        ),
      ),
      bottomNavigationBar: BlocBuilder<BillingBloc, BillingState>(
        builder: (context, state) {
          if (state.cartItems.isEmpty) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            child: PrimaryButton(
              onPressed: () async {
                await _pauseScanner();
                await context.push('/checkout');
                if (_isCameraOn && mounted) await _resumeScanner();
              },
              icon: Icons.payments_rounded,
              label:
                  'Review Order   •   ₹${state.totalAmount.toStringAsFixed(2)}',
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required String tooltip,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildElegantScannerCard() {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isSmallScreen = screenHeight < 720;
    final scannerViewportHeight = isSmallScreen ? 150.0 : 180.0;
    final scanFrameWidth = isSmallScreen ? 160.0 : 190.0;
    final scanFrameHeight = isSmallScreen ? 84.0 : 100.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isCameraOn
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isCameraOn ? 'Live' : 'Paused',
                  style: TextStyle(
                    color: _isCameraOn
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: scannerViewportHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraOn)
                    MobileScanner(
                      key: ValueKey('home-scanner-$_scannerWidgetVersion'),
                      controller: _scannerController,
                      onDetect: _onDetect,
                      errorBuilder: _buildScannerErrorState,
                    )
                  else
                    _buildCameraOffState(),
                  if (_isCameraOn)
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
                  if (_isCameraOn)
                    Center(
                      child: Container(
                        width: scanFrameWidth,
                        height: scanFrameHeight,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  if (_isCameraOn)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Column(
                        children: [
                          _buildOverlayIconButton(
                            icon: _isFlashOn
                                ? Icons.flashlight_off_rounded
                                : Icons.flashlight_on_rounded,
                            isActive: _isFlashOn,
                            onPressed: () {
                              setState(() => _isFlashOn = !_isFlashOn);
                              _scannerController.toggleTorch();
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildOverlayIconButton(
                            icon: Icons.videocam_off_rounded,
                            isActive: false,
                            onPressed: () {
                              setState(() {
                                _isCameraOn = false;
                              });
                              _pauseScanner();
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Point the camera at a barcode to add items instantly.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayIconButton({
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryColor
                  : Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraOffState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 170;

        return Container(
          color: const Color(0xFF0F172A), // Slate 900
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: compact ? 8 : 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(compact ? 9 : 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1E293B), // Slate 800
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            blurRadius: compact ? 10 : 14,
                            spreadRadius: compact ? 2 : 4,
                          )
                        ]),
                    child: Icon(Icons.videocam_off_rounded,
                        color: Colors.white, size: compact ? 20 : 24),
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Text(
                    'Tap to Scan',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 13 : 15,
                        letterSpacing: -0.5),
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10 : 14,
                          vertical: compact ? 6 : 8),
                      elevation: 0,
                    ),
                    icon: Icon(Icons.play_arrow_rounded, size: compact ? 14 : 16),
                    label: Text('Start Scanner',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: compact ? 10.5 : 12)),
                    onPressed: () async {
                      await _startScannerFromUserAction();
                    },
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 24,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: const Color(0xFF94A3B8),
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'Current Order'),
              Tab(text: 'Add Items'),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
    return BlocBuilder<BillingBloc, BillingState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: _buildSaleEntryStyleSection(
            child: state.cartItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 34),
                    child: _buildEmptyCart(),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${state.cartItems.length} items',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _clearAllGuestCart,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: const Color(0xFFFEF2F2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.delete_sweep_rounded,
                                  size: 16),
                              label: const Text('Clear All',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.cartItems.length,
                        separatorBuilder: (context, index) =>
                            Divider(color: Colors.grey.shade100, height: 1),
                        itemBuilder: (context, index) {
                          final item = state.cartItems[index];
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.inventory_2_rounded,
                                        size: 20, color: Color(0xFF64748B)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rs ${item.product.price.toStringAsFixed(2)} x ${_formatQty(item.quantity)} ${item.product.unit.shortLabel}',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rs ${item.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
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
                                                _decrementCartItem(item),
                                          ),
                                          SizedBox(
                                            width: 62,
                                            child: Text(
                                              _formatQtyWithUnit(
                                                  item.quantity,
                                                  item.product.unit),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          _circularIconButton(
                                            icon: Icons.add_rounded,
                                            color: AppTheme.primaryColor,
                                            onPressed: () =>
                                                _incrementCartItem(item),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_isWeightedUnit(item.product.unit)) ...[
                                      const SizedBox(height: 6),
                                      TextButton(
                                        onPressed: () =>
                                            _setManualQuantityForCartItem(item),
                                        style: TextButton.styleFrom(
                                          minimumSize: Size.zero,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
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
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: List.generate(
                            30,
                            (index) => Expanded(
                              child: Container(
                                height: 2,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                color: Colors.grey.shade200,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL AMOUNT',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Rs ${state.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryColor,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildInventoryTab() {
    return BlocBuilder<BillingBloc, BillingState>(
      builder: (context, state) {
        final cartByProductId = {
          for (final cartItem in state.cartItems) cartItem.product.id: cartItem,
        };

        return ValueListenableBuilder<TextEditingValue>(
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

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: _buildSaleEntryStyleSection(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _productSearchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search inventory…',
                                    hintStyle: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 14),
                                    prefixIcon: const Icon(Icons.search_rounded,
                                        color: Color(0xFF94A3B8), size: 20),
                                    suffixIcon: searchVal.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                                Icons.clear_rounded,
                                                color: Color(0xFF94A3B8),
                                                size: 20),
                                            onPressed: () {
                                              _productSearchController.clear();
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (filtered.isEmpty)
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 36),
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
                                          size: 34,
                                          color: Colors.grey.shade300),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('No products found',
                                        style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final product = filtered[index];
                                final cartItem = cartByProductId[product.id];
                                final inCart = cartItem != null;

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: inCart
                                        ? const Color(0xFFF8FAFC)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: inCart
                                        ? Border.all(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.35),
                                            width: 1.5)
                                        : Border.all(
                                            color: Colors.grey.shade100,
                                            width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                            Icons.inventory_2_rounded,
                                            color: AppTheme.primaryColor,
                                            size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(product.name,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    color: Color(0xFF1E293B))),
                                            const SizedBox(height: 4),
                                            Text(
                                                '₹${product.price.toStringAsFixed(2)} • Stock: ${product.stock} ${product.unit.shortLabel}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF94A3B8))),
                                          ],
                                        ),
                                      ),
                                      if (inCart)
                                        Container(
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.03),
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
                                                onPressed: () =>
                                                    _decrementCartItem(cartItem),
                                              ),
                                              SizedBox(
                                                width: 40,
                                                child: Text(
                                                  _formatQtyWithUnit(
                                                      cartItem.quantity,
                                                      product.unit),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 13,
                                                      color:
                                                          Color(0xFF0F172A)),
                                                ),
                                              ),
                                              _circularIconButton(
                                                icon: Icons.add_rounded,
                                                color: AppTheme.primaryColor,
                                                onPressed: () =>
                                                    _incrementCartItem(cartItem),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: () => _addProductFromInventory(
                                              product.toEntity()),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.primaryColor,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text('Add',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSaleEntryStyleSection({
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: child,
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // Slate 100
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]),
            child: const Icon(Icons.shopping_bag_outlined,
                size: 48, color: Color(0xFF94A3B8)), // Slate 400
          ),
          const SizedBox(height: 16),
          const Text('Your cart is empty',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Scan products or browse inventory to add items to your cart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circularIconButton(
      {required IconData icon,
      required VoidCallback onPressed,
      required Color color}) {
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
}
