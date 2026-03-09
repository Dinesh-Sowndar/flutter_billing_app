import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/billing_bloc.dart';
import '../../../../core/theme/app_theme.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          context.read<BillingBloc>().add(ClearCartEvent());
          context.go('/');
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
                context.read<BillingBloc>().add(ClearCartEvent());
                context.go('/');
              },
            ),
          ),
          body: BlocConsumer<BillingBloc, BillingState>(
            listener: (context, state) {
              if (state.printSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Printed successfully'),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))));
              }
            },
            builder: (context, billingState) {
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
                                                '${item.quantity} x ${item.product.name}',
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

                            // Payment QR Section (if exists)
                            if (upiId.isNotEmpty) ...[
                              const Text('Pay via UPI',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF64748B))),
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
                                        'upi://pay?pa=$upiId&pn=$shopName&am=${billingState.totalAmount.toStringAsFixed(2)}&cu=INR',
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
                                  context
                                      .read<BillingBloc>()
                                      .add(FinishTransactionEvent());
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
                                context.read<BillingBloc>().add(
                                    PrintReceiptEvent(
                                        shopName: shopState.shop.name,
                                        address1: shopState.shop.addressLine1,
                                        address2: shopState.shop.addressLine2,
                                        phone: shopState.shop.phoneNumber,
                                        footer: shopState.shop.footerText));
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
}
