import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/cart_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MobileScannerController _scannerController =
      MobileScannerController(
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

  void _onDetect(
    BarcodeCapture capture,
  ) async {
    final List<Barcode> barcodes =
        capture.barcodes;

    final now = DateTime.now();

    for (final barcode in barcodes) {
      if (barcode.rawValue == null) {
        continue;
      }

      final rawValue =
          barcode.rawValue!.trim();

      if (rawValue.isEmpty) {
        continue;
      }

      if (_lastScanTimes.containsKey(rawValue)) {
        final lastScan =
            _lastScanTimes[rawValue]!;

        if (now.difference(lastScan).inSeconds <
            2) {
          continue;
        }
      }

      _lastScanTimes[rawValue] = now;

      final hasVibrator =
          await Vibration.hasVibrator();

      if (hasVibrator == true) {
        Vibration.vibrate();
      }

      if (!mounted) {
        return;
      }

      context.read<BillingBloc>().add(
            ScanBarcodeEvent(
              rawValue,
            ),
          );

      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<BillingBloc, BillingState>(
        listenWhen: (
          previous,
          current,
        ) {
          return previous.error !=
                  current.error &&
              current.error != null;
        },
        listener: (context, state) {
          if (state.error == null) {
            return;
          }

          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: Text(
                state.error!,
              ),
              backgroundColor: Colors.red,
              behavior:
                  SnackBarBehavior.floating,
            ),
          );
        },
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.39,
              child:
                  _buildScannerSection(),
            ),

            Positioned(
              top:
                  (MediaQuery.of(context)
                              .size
                              .height *
                          0.39) -
                      24,
              left: 0,
              right: 0,
              bottom: 0,
              child:
                  _buildBottomPanel(),
            ),
          ],
        ),
      ),

      bottomSheet:
          _buildBottomActions(),
    );
  }

  Widget _buildBottomActions() {
    return BlocBuilder<BillingBloc, BillingState>(
      builder: (context, state) {
        return Container(
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                4,
                12,
                10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        _scannerController.stop();

                        await context.push(
                          '/manual-pos',
                        );

                        if (_isCameraOn &&
                            mounted) {
                          _scannerController
                              .start();
                        }
                      },
                      icon: const Icon(
                        Icons.point_of_sale,
                      ),
                      label: const Text(
                        'الكاشير اليدوي',
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(
                          52,
                        ),
                      ),
                    ),
                  ),

                  if (state.cartItems.isNotEmpty) ...[
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          _scannerController
                              .stop();

                          await context.push(
                            '/checkout',
                          );

                          if (_isCameraOn &&
                              mounted) {
                            _scannerController
                                .start();
                          }
                        },
                        icon: const Icon(
                          Icons.receipt_long,
                        ),
                        label: const Text(
                          'الفاتورة',
                        ),
                        style: ElevatedButton
                            .styleFrom(
                          minimumSize:
                              const Size.fromHeight(
                            52,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScannerSection() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isCameraOn)
            MobileScanner(
              controller:
                  _scannerController,
              onDetect: _onDetect,
            ),

          if (!_isCameraOn)
            _buildCameraOffState(),

          Positioned(
            top:
                MediaQuery.of(context)
                        .padding
                        .top +
                    12,
            right: 14,
            child: Column(
              children: [
                _buildOverlayButton(
                  icon: Icons.settings,
                  onPressed: () async {
                    _scannerController
                        .stop();

                    await context.push(
                      '/settings',
                    );

                    if (_isCameraOn &&
                        mounted) {
                      _scannerController
                          .start();
                    }
                  },
                ),

                if (_isCameraOn) ...[
                  const SizedBox(
                    height: 10,
                  ),
                  _buildOverlayButton(
                    icon: _isFlashOn
                        ? Icons.flashlight_off
                        : Icons.flashlight_on,
                    onPressed: () {
                      setState(() {
                        _isFlashOn =
                            !_isFlashOn;
                      });

                      _scannerController
                          .toggleTorch();
                    },
                  ),
                ],

                const SizedBox(
                  height: 10,
                ),

                _buildOverlayButton(
                  icon: _isCameraOn
                      ? Icons.videocam
                      : Icons.videocam_off,
                  onPressed: () {
                    setState(() {
                      _isCameraOn =
                          !_isCameraOn;
                    });

                    if (_isCameraOn) {
                      _scannerController
                          .start();
                    } else {
                      _scannerController
                          .stop();
                    }
                  },
                ),
              ],
            ),
          ),

          if (_isCameraOn)
            Center(
              child: Container(
                width: 230,
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white24,
                    width: 2,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: Stack(
                  children: [
                    _buildCorner(
                      Alignment.topLeft,
                    ),
                    _buildCorner(
                      Alignment.topRight,
                    ),
                    _buildCorner(
                      Alignment.bottomLeft,
                    ),
                    _buildCorner(
                      Alignment.bottomRight,
                    ),

                    const Center(
                      child: Text(
                        'ضع الباركود داخل الإطار',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color:
                              Colors.white70,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            top:
                MediaQuery.of(context)
                        .padding
                        .top +
                    14,
            left: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: const Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 17,
                  ),
                  SizedBox(
                    width: 6,
                  ),
                  Text(
                    'مسح الباركود',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraOffState() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration:
                const BoxDecoration(
              color:
                  Color(0xFF334155),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.videocam_off,
              color: Colors.white,
              size: 32,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            'الكاميرا متوقفة',
            style: TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.bold,
              fontSize: 17,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          const Padding(
            padding:
                EdgeInsets.symmetric(
              horizontal: 30,
            ),
            child: Text(
              'يمكنك تشغيل الكاميرا لمسح الباركود أو استخدام الكاشير اليدوي.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          ElevatedButton.icon(
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  AppTheme.primaryColor,
              foregroundColor:
                  Colors.white,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 12,
              ),
            ),
            icon: const Icon(
              Icons.videocam,
            ),
            label: const Text(
              'تشغيل الكاميرا',
            ),
            onPressed: () {
              setState(() {
                _isCameraOn = true;
              });

              _scannerController.start();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white24,
        ),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: Colors.white,
          size: 21,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCorner(
    Alignment alignment,
  ) {
    final bool isTop =
        alignment == Alignment.topLeft ||
            alignment == Alignment.topRight;

    final bool isBottom =
        alignment ==
                Alignment.bottomLeft ||
            alignment ==
                Alignment.bottomRight;

    final bool isLeft =
        alignment == Alignment.topLeft ||
            alignment ==
                Alignment.bottomLeft;

    final bool isRight =
        alignment == Alignment.topRight ||
            alignment ==
                Alignment.bottomRight;

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 30,
        height: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: isTop
                  ? const BorderSide(
                      color:
                          Colors.greenAccent,
                      width: 4,
                    )
                  : BorderSide.none,
              bottom: isBottom
                  ? const BorderSide(
                      color:
                          Colors.greenAccent,
                      width: 4,
                    )
                  : BorderSide.none,
              left: isLeft
                  ? const BorderSide(
                      color:
                          Colors.greenAccent,
                      width: 4,
                    )
                  : BorderSide.none,
              right: isRight
                  ? const BorderSide(
                      color:
                          Colors.greenAccent,
                      width: 4,
                    )
                  : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            offset: Offset(
              0,
              -5,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 4,
            margin:
                const EdgeInsets.symmetric(
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: Colors.grey
                  .withValues(alpha: 0.3),
              borderRadius:
                  BorderRadius.circular(2),
            ),
          ),

          BlocBuilder<BillingBloc,
              BillingState>(
            builder: (
              context,
              state,
            ) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Text(
                            'سلة المشتريات',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            '${state.totalQuantity} قطعة',
                            style: const TextStyle(
                              fontSize: 12,
                              color:
                                  Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'الإجمالي',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(
                          height: 2,
                        ),
                        Text(
                          '${_formatMoney(state.totalAmount)} DZD',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w900,
                            color:
                                AppTheme
                                    .primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(
            height: 1,
          ),

          Expanded(
            child: BlocBuilder<
                BillingBloc,
                BillingState>(
              builder: (
                context,
                state,
              ) {
                if (state.cartItems.isEmpty) {
                  return _buildEmptyCart();
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(
                    14,
                    14,
                    14,
                    95,
                  ),
                  itemCount:
                      state.cartItems.length,
                  separatorBuilder: (
                    context,
                    index,
                  ) {
                    return const SizedBox(
                      height: 9,
                    );
                  },
                  itemBuilder: (
                    context,
                    index,
                  ) {
                    return _buildCartItemCard(
                      context,
                      state.cartItems[index],
                    );
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              alignment:
                  Alignment.center,
              child: Icon(
                Icons.shopping_basket_outlined,
                size: 36,
                color: Colors.grey[300],
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            const Text(
              'السلة فارغة',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 17,
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            const Text(
              'امسح باركود المنتج أو افتح الكاشير اليدوي لإضافة المنتجات.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(
    BuildContext context,
    CartItem item,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: Colors.grey[200]!,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  '${_formatMoney(item.product.price)} DZD',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 13,
                    color:
                        Colors.grey[600],
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  'المجموع: ${_formatMoney(item.total)} DZD',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        AppTheme.primaryColor,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius:
                  BorderRadius.circular(9),
            ),
            padding:
                const EdgeInsets.all(3),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                _quantityButton(
                  icon: Icons.remove,
                  onPressed: () {
                    if (item.quantity > 1) {
                      context
                          .read<BillingBloc>()
                          .add(
                            UpdateQuantityEvent(
                              item.product.id,
                              item.quantity - 1,
                            ),
                          );
                    } else {
                      context
                          .read<BillingBloc>()
                          .add(
                            RemoveProductFromCartEvent(
                              item.product.id,
                            ),
                          );
                    }
                  },
                ),

                SizedBox(
                  width: 30,
                  child: Text(
                    '${item.quantity}',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                _quantityButton(
                  icon: Icons.add,
                  onPressed: () {
                    context
                        .read<BillingBloc>()
                        .add(
                          UpdateQuantityEvent(
                            item.product.id,
                            item.quantity + 1,
                          ),
                        );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius:
          BorderRadius.circular(8),
      child: Padding(
        padding:
            const EdgeInsets.all(5),
        child: Icon(
          icon,
          size: 18,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  String _formatMoney(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }
}
