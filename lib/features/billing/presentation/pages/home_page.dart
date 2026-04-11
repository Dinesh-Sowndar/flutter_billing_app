import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:ui';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:billing_app/features/billing/presentation/bloc/billing_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:billing_app/features/billing/domain/entities/cart_item.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/service_locator.dart' as di;
import '../../../../core/services/sync_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const String _scannerVisibilityKeyPrefix = 'scanner_visible';
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
  bool _autoHiddenByManualAdd = false;
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
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _scannerController = _createScannerController();
  }

  bool _isScannerVisibleByUserSetting() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return true;
    final key = '${_scannerVisibilityKeyPrefix}_$uid';
    return HiveDatabase.settingsBox.get(key, defaultValue: true) == true;
  }

  Future<void> _applyScannerVisibilitySetting({bool refreshUi = false}) async {
    if (!mounted) return;
    final isVisible = _isScannerVisibleByUserSetting();

    if (!isVisible) {
      if (_isCameraOn || _scannerRunning || _autoHiddenByManualAdd) {
        setState(() {
          _isCameraOn = false;
          _scannerRunning = false;
          _autoHiddenByManualAdd = false;
        });
      } else if (refreshUi) {
        setState(() {});
      }
      await _pauseScanner();
      return;
    }

    if (refreshUi && mounted) {
      setState(() {});
    }
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
    if (!_isScannerVisibleByUserSetting()) {
      if (mounted && (_isCameraOn || _scannerRunning)) {
        setState(() {
          _isCameraOn = false;
          _scannerRunning = false;
        });
      }
      return;
    }

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
    if (!_isScannerVisibleByUserSetting()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scanner is disabled in Settings for this account.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

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
    if (_resumeScheduled || !_isCameraOn || !_isScannerVisibleByUserSetting()) {
      return;
    }
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

  void _applyInlineQuantityForCartItem(CartItem item, String rawValue) {
    final qty = double.tryParse(rawValue.trim());
    if (qty == null) return;
    _markScannerActive();
    if (qty <= 0) {
      context
          .read<BillingBloc>()
          .add(RemoveProductFromCartEvent(item.product.id));
      return;
    }
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
    _markScannerActive();
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
    _markScannerActive();
    final step = _stepForUnit(item.product.unit);
    if (item.quantity > step) {
      context
          .read<BillingBloc>()
          .add(UpdateQuantityEvent(item.product.id, item.quantity - step));
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
  }

  void _addProductFromInventory(
    Product product, {
    bool hideScannerForManual = false,
  }) {
    if (hideScannerForManual) {
      _hideScannerForManualEntry();
    } else {
      _markScannerActive();
    }
    context.read<BillingBloc>().add(AddProductToCartEvent(product));

    Vibrate.canVibrate.then((can) {
      if (can) {
        Vibrate.feedback(FeedbackType.light);
      }
    });
  }

  void _hideScannerForManualEntry() {
    if (!mounted) return;
    if (_autoHiddenByManualAdd && !_isCameraOn) return;
    setState(() {
      _autoHiddenByManualAdd = true;
      _isCameraOn = false;
      _scannerRunning = false;
    });
    unawaited(_pauseScanner());
  }

  Future<void> _showScannerAgain() async {
    if (!mounted) return;
    setState(() {
      _autoHiddenByManualAdd = false;
    });
    await _startScannerFromUserAction();
  }

  @override
  Widget build(BuildContext context) {
    _ensureScannerActiveSoon();
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = keyboardInset > 0;
    final scannerVisibleBySetting = _isScannerVisibleByUserSetting();
    final shouldHideScannerPanel =
        isKeyboardOpen || !scannerVisibleBySetting || _autoHiddenByManualAdd;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA), // Elegant light background
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Receipt',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20.sp,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(width: 8.w),
            _SyncDot(),
          ],
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
              if (!mounted) return;
              await _applyScannerVisibilitySetting(refreshUi: true);
              if (_isCameraOn && _isScannerVisibleByUserSetting()) {
                await _resumeScanner();
              }
            },
          ),
          SizedBox(width: 8.w),
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
                    borderRadius: BorderRadius.circular(12.r)),
                margin: EdgeInsets.all(16.r),
              ),
            );
          }
        },
        child: Column(
          children: [
            Offstage(
              offstage: shouldHideScannerPanel,
              child: _buildElegantScannerCard(),
            ),
            if (_autoHiddenByManualAdd && scannerVisibleBySetting)
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _showScannerAgain,
                    icon: const Icon(Icons.videocam_rounded, size: 16),
                    label: const Text('Show Scanner'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(height: isKeyboardOpen ? 6.h : 14.h),
            Expanded(child: _buildBottomPanel()),
          ],
        ),
      ),
      bottomNavigationBar: BlocBuilder<BillingBloc, BillingState>(
        builder: (context, state) {
          if (state.cartItems.isEmpty || keyboardInset > 0) {
            return const SizedBox.shrink();
          }

          return Container(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 14.h),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20.r,
                  offset: Offset(0, -5.h),
                )
              ],
            ),
            child: SizedBox(
              height: 46.h,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _pauseScanner();
                  await context.push('/checkout');
                  if (_isCameraOn && mounted) await _resumeScanner();
                },
                icon: Icon(Icons.payments_rounded, size: 18.r),
                label: Text(
                  'Review Order   •   ₹${state.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.35),
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
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
      padding: EdgeInsets.symmetric(horizontal: 4.0.w),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side:
              BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(8.0.r),
            child: Icon(icon, color: iconColor, size: 22.r),
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
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Scanner',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: _isCameraOn
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  _isCameraOn ? 'Live' : 'Paused',
                  style: TextStyle(
                    color: _isCameraOn
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontWeight: FontWeight.w800,
                    fontSize: 11.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(22.r),
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
                        width: scanFrameWidth.w,
                        height: scanFrameHeight.h,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 2.w),
                          borderRadius: BorderRadius.circular(20.r),
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
          SizedBox(height: 10.h),
          Text(
            'Point the camera at a barcode to add items instantly.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12.5.sp,
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
      borderRadius: BorderRadius.circular(14.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryColor
                  : Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 22.r),
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
                            blurRadius: compact ? 10.r : 14.r,
                            spreadRadius: compact ? 2.r : 4.r,
                          )
                        ]),
                    child: Icon(Icons.videocam_off_rounded,
                        color: Colors.white, size: compact ? 20.r : 24.r),
                  ),
                  SizedBox(height: compact ? 8.h : 10.h),
                  Text(
                    'Tap to Scan',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 13.sp : 15.sp,
                        letterSpacing: -0.5),
                  ),
                  SizedBox(height: compact ? 6.h : 8.h),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                      padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10.w : 14.w,
                          vertical: compact ? 6.h : 8.h),
                      elevation: 0,
                    ),
                    icon: Icon(Icons.play_arrow_rounded,
                        size: compact ? 14.r : 16.r),
                    label: Text('Start Scanner',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: compact ? 10.5.sp : 12.sp)),
                    onPressed: () async {
                      if (!_isScannerVisibleByUserSetting()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Scanner is disabled in Settings for this account.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _autoHiddenByManualAdd = false;
                      });
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 24.r,
            offset: Offset(0, -4.h),
          )
        ],
      ),
      child: Column(
        children: [
          SizedBox(height: 8.h),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4.r,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp),
              unselectedLabelStyle:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_rounded, size: 18.r),
                      SizedBox(width: 8.w),
                       Text('Current Order',style: TextStyle(fontSize: 12.sp),),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 18.r),
                      SizedBox(width: 8.w),
                       Text('Add Items', style: TextStyle(fontSize: 12.sp)),
                    ],
                  ),
                ),
              ],
            ),
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
        if (state.cartItems.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
              child: _buildSaleEntryStyleSection(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 34.h),
                  child: _buildEmptyCart(),
                ),
              ),
            ),
          );
        }

        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20.w,
            16.h,
            20.w,
            keyboardInset +
                (state.cartItems.isNotEmpty && keyboardInset == 0
                    ? 24.h
                    : 110.h),
          ),
          child: _buildSaleEntryStyleSection(
            child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
                        child: Row(
                          children: [
                            Text(
                              'Current Order',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16.sp,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${state.cartItems.length} item(s)',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            GestureDetector(
                              onTap: _clearAllGuestCart,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: const Color(0xFFEF4444),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.cartItems.length,
                        itemBuilder: (context, index) {
                          final item = state.cartItems[index];
                          return Container(
                            margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                            padding: EdgeInsets.all(16.r),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                  color: Colors.grey.shade100, width: 1.5.w),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10.r,
                                  offset: Offset(0, 4.h),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.sp,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        'Rs ${item.product.price.toStringAsFixed(0)} x ${_formatQty(item.quantity)} ${item.product.unit.shortLabel}  =  Rs ${item.total.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      height: 36.h,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius:
                                            BorderRadius.circular(12.r),
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
                                            width: 56.w,
                                            child: _isWeightedUnit(
                                                    item.product.unit)
                                                ? TextFormField(
                                                    key: ValueKey(
                                                        '${item.product.id}-${item.quantity}'),
                                                    initialValue: _formatQty(
                                                        item.quantity),
                                                    keyboardType:
                                                        const TextInputType
                                                            .numberWithOptions(
                                                            decimal: true),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12.sp,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                    decoration:
                                                        const InputDecoration(
                                                      isDense: true,
                                                      border: InputBorder.none,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                    ),
                                                    onFieldSubmitted: (value) {
                                                      _applyInlineQuantityForCartItem(
                                                          item, value);
                                                    },
                                                  )
                                                : Text(
                                                    _formatQty(item.quantity),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 13.sp,
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
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
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
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final cartByProductId = {
          for (final cartItem in state.cartItems) cartItem.product.id: cartItem,
        };

        return Column(
          children: [
            // ── Header w/ View All ───────────────────────────────────────────
            Container(
              color: const Color(0xFFFBFCFE),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Items',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await _pauseScanner();
                      await context.push('/product-search');
                      if (_isCameraOn && mounted) await _resumeScanner();
                    },
                    icon: Icon(Icons.search_rounded, size: 18.r),
                    label: const Text('View All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding:
                          EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            // ── Product list (scrollable, takes remaining space) ──────────
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: HiveDatabase.productBox.listenable(),
                builder: (context, box, _) {
                  final allProducts = box.values.toList();
                  final filteredList = allProducts;

                  if (filteredList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72.w,
                            height: 72.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(24.r),
                            ),
                            child: Icon(Icons.inventory_2_outlined,
                                size: 34.r, color: Colors.grey.shade300),
                          ),
                          SizedBox(height: 12.h),
                          Text('No products found',
                              style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16.w,
                      8.h,
                      16.w,
                      keyboardInset +
                          (state.cartItems.isNotEmpty && keyboardInset == 0
                              ? 24.h
                              : 110.h),
                    ),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (context, index) {
                      final product = filteredList[index];
                      final cartItem = cartByProductId[product.id];
                      final inCart = cartItem != null;

                      return Container(
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color:
                              inCart ? const Color(0xFFF8FAFC) : Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          border: inCart
                              ? Border.all(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.35),
                                  width: 1.5.w)
                              : Border.all(
                                  color: Colors.grey.shade100, width: 1.5.w),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 12.r,
                              offset: Offset(0, 4.h),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46.w,
                              height: 46.h,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Icon(Icons.inventory_2_rounded,
                                  color: AppTheme.primaryColor, size: 20.r),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.sp,
                                          color: Color(0xFF1E293B))),
                                  SizedBox(height: 3.h),
                                  Text(
                                    '₹${product.price.toStringAsFixed(2)} • ${product.stock} ${product.unit.shortLabel}',
                                    style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            if (inCart)
                              Container(
                                height: 38.h,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4.r,
                                      offset: Offset(0, 2.h),
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
                                      width: _isWeightedUnit(product.unit)
                                          ? 56.w
                                          : 40.w,
                                      child: _isWeightedUnit(product.unit)
                                          ? TextFormField(
                                              key: ValueKey(
                                                  '${cartItem.product.id}-${cartItem.quantity}'),
                                              initialValue:
                                                  _formatQty(cartItem.quantity),
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13.sp,
                                                color: Color(0xFF0F172A),
                                              ),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              onFieldSubmitted: (value) {
                                                _applyInlineQuantityForCartItem(
                                                    cartItem, value);
                                              },
                                            )
                                          : Text(
                                              _formatQtyWithUnit(
                                                  cartItem.quantity,
                                                  product.unit),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13.sp,
                                                  color:
                                                      const Color(0xFF0F172A)),
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
                                  product.toEntity(),
                                  hideScannerForManual: true,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10.r)),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16.w, vertical: 8.h),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text('Add',
                                    style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 14.r,
            offset: Offset(0, 6.h),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.w),
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
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded, color: Colors.white, size: 48.r),
          SizedBox(height: 12.h),
          Text(
            isPermissionError
                ? 'Camera permission is required for scanning.'
                : 'Unable to open camera. Please retry.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
          ),
          SizedBox(height: 16.h),
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
            SizedBox(height: 8.h),
            Text(
              _cameraErrorMessage!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12.sp),
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
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // Slate 100
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10.r,
                    offset: Offset(0, 4.h),
                  )
                ]),
            child: Icon(Icons.shopping_bag_outlined,
                size: 48.r, color: const Color(0xFF94A3B8)), // Slate 400
          ),
          SizedBox(height: 16.h),
          Text('Your cart is empty',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18.sp,
                  letterSpacing: -0.5,
                  color: Color(0xFF0F172A))),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48.w),
            child: Text(
              'Scan products or browse inventory to add items to your cart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13.sp,
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
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          width: 36.w,
          height: 36.h,
          alignment: Alignment.center,
          child: Icon(icon, size: 18.r, color: color),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated sync status dot shown next to the AppBar title.
// Self-contained: subscribes to Hive box changes + SyncService.onSyncComplete
// so it updates both when offline (Hive write) and after online sync.
// ---------------------------------------------------------------------------
class _SyncDot extends StatefulWidget {
  const _SyncDot();

  @override
  State<_SyncDot> createState() => _SyncDotState();
}

class _SyncDotState extends State<_SyncDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Listenable _hiveListenable;
  StreamSubscription<void>? _syncSub;
  bool _synced = true;

  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();

    // Animation controller
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    // Listen to every relevant Hive box — fires on every read/write, offline or online
    _hiveListenable = Listenable.merge([
      HiveDatabase.transactionBox.listenable(),
      HiveDatabase.productBox.listenable(),
      HiveDatabase.categoryBox.listenable(),
      HiveDatabase.supplierBox.listenable(),
      HiveDatabase.supplierPurchaseBox.listenable(),
      HiveDatabase.customerBox.listenable(),
      HiveDatabase.settingsBox.listenable(),
    ]);
    _hiveListenable.addListener(_refresh);

    // Also listen to SyncService.onSyncComplete (fires after online sync clears flags)
    _syncSub =
        di.sl<SyncService>().onSyncComplete.stream.listen((_) => _refresh());

    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    final synced = !HiveDatabase.hasUnsyncedData();
    if (synced == _synced) return;
    setState(() => _synced = synced);
    if (_synced) {
      _ctrl.stop();
      _ctrl.value = 0;
    } else {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _hiveListenable.removeListener(_refresh);
    _syncSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _synced ? _green : _amber;
    return ScaleTransition(
      scale: _synced ? const AlwaysStoppedAnimation(1.0) : _scale,
      child: Container(
        width: 10.r,
        height: 10.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: _synced ? 0.35 : 0.6),
              blurRadius: 6.r,
              spreadRadius: 1.r,
            ),
          ],
        ),
      ),
    );
  }
}
