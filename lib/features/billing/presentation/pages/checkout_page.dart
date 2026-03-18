import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../customer/presentation/bloc/customer_bloc.dart';
import '../../../customer/presentation/bloc/customer_event.dart';
import '../../../product/domain/entities/product.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/billing_bloc.dart';
import '../../../../core/theme/app_theme.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _amountPaidController = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isInitialized = false;
  bool _isPaymentDetailsExpanded = false;
  double _qrAmount = 0.0;

  @override
  void dispose() {
    _amountPaidController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          _handleCheckoutExit(context);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Checkout',
                style: TextStyle(
                    fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded,
                  size: 32, color: Theme.of(context).primaryColor),
              onPressed: () {
                _handleCheckoutExit(context);
              },
            ),
          ),
          body: BlocConsumer<BillingBloc, BillingState>(
            listener: (context, state) {
              if (state.printSuccess) {
                // Inform global CustomerBloc to refresh data
                context.read<CustomerBloc>().add(LoadCustomersEvent());

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Transaction completed successfully'),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))));
                context.read<BillingBloc>().add(ClearCartEvent());
                context.go('/');
              }
            },
            builder: (context, billingState) {
              if (!_isInitialized && billingState.totalAmount > 0) {
                _amountPaidController.text =
                    billingState.totalAmount.toStringAsFixed(2);
                _qrAmount = billingState.totalAmount;
                _isInitialized = true;
              }

              return BlocBuilder<ShopBloc, ShopState>(
                  builder: (context, shopState) {
                String upiId = '';
                String shopName = 'Shop';

                if (shopState is ShopLoaded) {
                  upiId = shopState.shop.upiId;
                  shopName = shopState.shop.name;
                }

                return Column(
                  children: [
                    // Digital Receipt Area
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: Column(
                          children: [
                            // Sleek Receipt Card
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                    width: 2), // Slate 100
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF0F172A)
                                          .withValues(alpha: 0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8))
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Shop Header
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(22)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.receipt_long_rounded,
                                            color: AppTheme.primaryColor),
                                        const SizedBox(width: 8),
                                        Text('Order Summary',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: AppTheme.primaryColor
                                                    .withValues(alpha: 0.8))),
                                      ],
                                    ),
                                  ),

                                  // The Table
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Table(
                                      columnWidths: const {
                                        0: FlexColumnWidth(2),
                                        1: FlexColumnWidth(1),
                                        2: FlexColumnWidth(1.2),
                                      },
                                      children: [
                                        // Header row
                                        TableRow(
                                          children: [
                                            _buildHeaderCell(
                                                'Item', TextAlign.left),
                                            _buildHeaderCell(
                                                'Price', TextAlign.right),
                                            _buildHeaderCell(
                                                'Total', TextAlign.right),
                                          ],
                                        ),
                                        // Items rows
                                        ...billingState.cartItems.map((item) {
                                          return TableRow(
                                            children: [
                                              _buildDataCell(
                                                '${_formatQty(item.quantity)} ${item.product.unit.shortLabel} x ${item.product.name}',
                                                TextAlign.left,
                                              ),
                                              _buildDataCell(
                                                  '₹${item.product.price.toStringAsFixed(2)}',
                                                  TextAlign.right,
                                                  isSubtitle: true),
                                              _buildDataCell(
                                                  '₹${item.total.toStringAsFixed(2)}',
                                                  TextAlign.right,
                                                  isBold: true),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ),

                                  // Divider Line (dashed look ideally, but simple line for now)
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 24),
                                    child: Divider(color: Color(0xFFE2E8F0)),
                                  ),

                                  // Subtotal/Total area inside receipt
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('TOTAL',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF94A3B8),
                                                letterSpacing: 1.2)),
                                        Text(
                                            '₹${billingState.totalAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF1E293B),
                                                letterSpacing: -0.5)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Credit Payment Details (customer mode only)
                            if (billingState.customerId.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: const Color(0xFFF1F5F9), width: 2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isPaymentDetailsExpanded =
                                              !_isPaymentDetailsExpanded;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6, horizontal: 2),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Credit Payment Details',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1E293B))),
                                            AnimatedRotation(
                                              turns: _isPaymentDetailsExpanded
                                                  ? 0.5
                                                  : 0,
                                              duration: const Duration(
                                                  milliseconds: 200),
                                              child: const Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    AnimatedCrossFade(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      crossFadeState: _isPaymentDetailsExpanded
                                          ? CrossFadeState.showFirst
                                          : CrossFadeState.showSecond,
                                      firstChild: Column(
                                        children: [
                                          const SizedBox(height: 12),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    TextFormField(
                                                      controller:
                                                          _amountPaidController,
                                                      keyboardType:
                                                          const TextInputType
                                                              .numberWithOptions(
                                                              decimal: true),
                                                      decoration:
                                                          InputDecoration(
                                                        labelText:
                                                            'Amount Willing to Pay',
                                                        prefixText: '₹ ',
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                      ),
                                                      onChanged: (val) {
                                                        setState(() {});
                                                      },
                                                    ),
                                                    const SizedBox(height: 12),
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: FilledButton.icon(
                                                        onPressed: () {
                                                          setState(() {
                                                            _qrAmount = double.tryParse(
                                                                    _amountPaidController
                                                                        .text) ??
                                                                0.0;
                                                          });
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                                  SnackBar(
                                                            content: Text(
                                                                'QR amount updated to ₹${_qrAmount.toStringAsFixed(2)}'),
                                                            behavior:
                                                                SnackBarBehavior
                                                                    .floating,
                                                            duration:
                                                                const Duration(
                                                                    seconds: 1),
                                                          ));
                                                        },
                                                        icon: const Icon(
                                                            Icons
                                                                .qr_code_2_rounded,
                                                            size: 18),
                                                        label: const Text(
                                                            'Update Amount'),
                                                        style: FilledButton
                                                            .styleFrom(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 14),
                                                          textStyle:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: DropdownButtonFormField<
                                                    String>(
                                                  value: _paymentMethod,
                                                  decoration: InputDecoration(
                                                    labelText: 'Method',
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                  items: const [
                                                    DropdownMenuItem(
                                                        value: 'cash',
                                                        child: Text('Cash')),
                                                    DropdownMenuItem(
                                                        value: 'upi',
                                                        child: Text('UPI')),
                                                    DropdownMenuItem(
                                                        value: 'card',
                                                        child: Text('Card')),
                                                  ],
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setState(() {
                                                        _paymentMethod = val;
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (billingState
                                              .customerId.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Builder(builder: (context) {
                                              final total =
                                                  billingState.totalAmount;
                                              final paid =
                                                  _parseWillingToPay(total);
                                              final due = total - paid;
                                              if (due > 0) {
                                                return Text(
                                                  'Remaining ₹${due.toStringAsFixed(2)} will be added to ${billingState.customerName}\'s ledger.',
                                                  style: const TextStyle(
                                                      color: Colors.orange,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            }),
                                          ],
                                        ],
                                      ),
                                      secondChild: const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            if (billingState.customerId.isNotEmpty)
                              const SizedBox(height: 32),

                            // Payment QR Section (if exists)
                            if (upiId.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Pay via UPI',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B))),
                                  Text(
                                    'Amount: ₹${_qrAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: const Color(0xFFF1F5F9), width: 2),
                                ),
                                child: SizedBox(
                                  width: 160,
                                  height: 160,
                                  child: PrettyQrView.data(
                                    data:
                                        'upi://pay?pa=$upiId&pn=$shopName&am=${_qrAmount.toStringAsFixed(2)}&cu=INR',
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(
                                height: 120), // padding for bottom fixed bar
                          ],
                        ),
                      ),
                    ),

                    // Bottom Floating Action Area
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      child: Column(
                        children: [
                          if (billingState.cartItems.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final paid =
                                      billingState.customerId.isNotEmpty
                                          ? _parseWillingToPay(
                                              billingState.totalAmount)
                                          : billingState.totalAmount;
                                  context.read<BillingBloc>().add(
                                      FinishTransactionEvent(
                                          amountPaid: paid,
                                          paymentMethod: _paymentMethod));
                                },
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  side: const BorderSide(
                                      color: AppTheme.primaryColor, width: 2),
                                ),
                                icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: AppTheme.primaryColor),
                                label: const Text('Finish without Receipt',
                                    style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                            ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            onPressed: () {
                              if (shopState is ShopLoaded) {
                                final paid = billingState.customerId.isNotEmpty
                                    ? _parseWillingToPay(
                                        billingState.totalAmount)
                                    : billingState.totalAmount;
                                context
                                    .read<BillingBloc>()
                                    .add(PrintReceiptEvent(
                                      shopName: shopState.shop.name,
                                      address1: shopState.shop.addressLine1,
                                      address2: shopState.shop.addressLine2,
                                      phone: shopState.shop.phoneNumber,
                                      footer: shopState.shop.footerText,
                                      amountPaid: paid,
                                      paymentMethod: _paymentMethod,
                                    ));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Shop details not loaded'),
                                        backgroundColor: Colors.red));
                              }
                            },
                            label: 'Print Receipt & Finish',
                            icon: Icons.print_rounded,
                            isLoading: billingState.isPrinting,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              });
            },
          ),
        ));
  }

  Widget _buildHeaderCell(String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Color(0xFF94A3B8), // Slate 400
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, TextAlign align,
      {bool isBold = false, bool isSubtitle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isSubtitle ? 13 : 15,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          color: isSubtitle ? const Color(0xFF64748B) : const Color(0xFF1E293B),
        ),
      ),
    );
  }

  double _parseWillingToPay(double totalAmount) {
    final parsed = double.tryParse(_amountPaidController.text.trim()) ?? 0.0;
    if (parsed.isNaN || parsed.isInfinite) return 0.0;
    if (parsed < 0) return 0.0;
    if (parsed > totalAmount) return totalAmount;
    return parsed;
  }

  void _handleCheckoutExit(BuildContext context) {
    final billingState = context.read<BillingBloc>().state;

    // Preserve cart in guest-mode so user can go back and edit/add items.
    if (billingState.customerId.isNotEmpty) {
      context.read<BillingBloc>().add(ClearCartEvent());
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}
