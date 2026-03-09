import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:ui';

import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../billing/presentation/bloc/sales_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/cart_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );

  bool _isCameraOn = true;
  bool _isFlashOn = false;

  final Map<String, DateTime> _lastScanTimes = {};

  @override
  void dispose() {
    _scannerController.dispose();
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

  @override
  Widget build(BuildContext context) {
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
              top: (MediaQuery.of(context).size.height * 0.45) - 32,
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
                        _scannerController.stop();
                        await context.push('/checkout');
                        if (_isCameraOn && mounted) _scannerController.start();
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
            controller: _scannerController,
            onDetect: _onDetect,
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
                  _scannerController.stop();
                  await context.push('/settings');
                  if (_isCameraOn && mounted) _scannerController.start();
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
                    _scannerController.start();
                  } else {
                    _scannerController.stop();
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
                  _scannerController.stop();
                  await context.push('/products');
                  if (_isCameraOn && mounted) _scannerController.start();
                },
                color: AppTheme.primaryColor.withValues(alpha: 0.8),
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
              _scannerController.start();
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
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1), // Slate 300
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Header
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              final totalItems =
                  state.cartItems.fold<int>(0, (sum, i) => sum + i.quantity);
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Order',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text('$totalItems items scanned',
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('TOTAL',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 1.2)),
                        const SizedBox(height: 2),
                        Text(
                          '₹${state.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).primaryColor,
                              letterSpacing: -1),
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
            child: Divider(height: 1, color: Color(0xFFE2E8F0)), // Slate 200
          ),

          // List View
          Expanded(
            child: BlocBuilder<BillingBloc, BillingState>(
              builder: (context, state) {
                if (state.cartItems.isEmpty) {
                  return _buildEmptyCart();
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, top: 16, bottom: 120),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04), // Slate 900
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon or color indicator
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${item.product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Quantity Selector
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC), // Slate 50
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)), // Slate 200
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _circularIconButton(
                    icon: Icons.remove_rounded,
                    onPressed: () {
                      if (item.quantity > 1) {
                        context.read<BillingBloc>().add(UpdateQuantityEvent(
                            item.product.id, item.quantity - 1));
                      } else {
                        context
                            .read<BillingBloc>()
                            .add(RemoveProductFromCartEvent(item.product.id));
                      }
                    }),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _circularIconButton(
                    icon: Icons.add_rounded,
                    onPressed: () {
                      context.read<BillingBloc>().add(UpdateQuantityEvent(
                          item.product.id, item.quantity + 1));
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
                                AppTheme.primaryColor)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildSalesCard('This Week',
                                state.weeklySales, const Color(0xFF3B82F6))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _buildSalesCard('This Month',
                                state.monthlySales, const Color(0xFF8B5CF6))),
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
                      ...state.recentTransactions.take(3).map((t) => Container(
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
                                    Text('${t.items.length} items',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    Text(
                                      '${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')} - ${t.date.day}/${t.date.month}/${t.date.year}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                                Text('₹${t.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: Color(0xFF1E293B))),
                              ],
                            ),
                          )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesCard(String title, double amount, Color color) {
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
        ],
      ),
    );
  }
}
