import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../customer/presentation/bloc/customer_bloc.dart';
import '../../../customer/presentation/bloc/customer_event.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/entities/cart_item.dart';
import '../../../settings/presentation/bloc/printer_bloc.dart';
import '../../../settings/presentation/bloc/printer_event.dart';
import '../../../settings/presentation/bloc/printer_state.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/billing_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/service_locator.dart' as di;
import '../../../../core/services/sync_service.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _amountPaidController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  String _paymentMethod = 'cash';
  double _qrAmount = 0.0;
  bool _isFinishing = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    // Verify printer connection status when entering checkout
    context.read<PrinterBloc>().add(CheckConnectionEvent());
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    _amountFocusNode.dispose();
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

  String _formatCheckoutQty(CartItem item) {
    if (item.product.unit == QuantityUnit.pieceWithKg) {
      final pieces = item.secondaryQuantity <= 0
          ? '0'
          : item.secondaryQuantity.toStringAsFixed(0);
      return '${_formatQty(item.quantity)} kg + $pieces pc';
    }
    return '${_formatQty(item.quantity)} ${item.product.unit.shortLabel}';
  }

  void _handleCheckoutExit(BuildContext context) {
    final billingState = context.read<BillingBloc>().state;
    if (billingState.customerId.isNotEmpty) {
      context.read<BillingBloc>().add(ClearCartEvent());
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  double _parseWillingToPay(double totalAmount) {
    final parsed = double.tryParse(_amountPaidController.text.trim()) ?? 0.0;
    if (parsed.isNaN || parsed.isInfinite) return 0.0;
    if (parsed < 0) return 0.0;
    if (parsed > totalAmount) return totalAmount;
    return parsed;
  }

  void _showCheckoutValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  double? _validatedCustomerAmountToPay(double totalAmount) {
    final text = _amountPaidController.text.trim();
    if (text.isEmpty) {
      _showCheckoutValidationError('Please enter amount customer will pay.');
      _amountFocusNode.requestFocus();
      return null;
    }

    final parsed = double.tryParse(text);
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
      _showCheckoutValidationError('Please enter a valid payment amount.');
      _amountFocusNode.requestFocus();
      return null;
    }

    if (parsed > totalAmount) {
      _showCheckoutValidationError(
        'Amount cannot exceed Rs ${totalAmount.toStringAsFixed(2)}.',
      );
      _amountFocusNode.requestFocus();
      return null;
    }

    return parsed;
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
        backgroundColor: const Color(0xFFF8FAFC),
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title:  Text(
            'Checkout',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20.sp,
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
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: const Color(0xFF0F172A),
                  onPressed: () => _handleCheckoutExit(context),
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: BlocBuilder<PrinterBloc, PrinterState>(
                builder: (context, printerState) {
                  final status = printerState.status;
                  final isConnected = printerState.isLiveConnected;
                  final isBusy = printerState.isBusy;
                  final statusLabel = switch (status) {
                    PrinterStatus.connecting => 'Connecting…',
                    PrinterStatus.scanning => 'Scanning…',
                    PrinterStatus.checking => 'Checking…',
                    PrinterStatus.testPrinting => 'Printing…',
                    PrinterStatus.connected => 'Printer On',
                    _ => 'Printer Off',
                  };
                  final statusColor = isConnected
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626);

                  return Material(
                    color: isConnected
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isBusy
                          ? null
                          : isConnected
                              ? null
                              : () => context
                                  .read<PrinterBloc>()
                                  .add(RefreshPrinterEvent()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isBusy)
                              const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5))
                            else
                              Icon(
                                Icons.print_rounded,
                                size: 16,
                                color: statusColor,
                              ),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                            if (!isConnected && !isBusy) ...[
                               SizedBox(width: 4.w),
                               Icon(Icons.refresh_rounded,
                                  size: 12.h, color: Color(0xFFDC2626)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            if (state.printSuccess) {
              if (mounted) {
                setState(() {
                  _isFinishing = false;
                  _isPrinting = false;
                });
              }
              final isOnline = di.sl<SyncService>().isOnline;
              context.read<CustomerBloc>().add(LoadCustomersEvent());
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      isOnline
                          ? 'Transaction completed successfully'
                          : 'Transaction saved locally. Will sync when online.',
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ));
              context.read<BillingBloc>().add(ClearCartEvent());
              context.go('/');
              return;
            }

            if (state.error != null && state.error!.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _isFinishing = false;
                  _isPrinting = false;
                });
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: const Color(0xFFDC2626),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            }
          },
          builder: (context, billingState) {
            final grandTotal = billingState.totalAmount +
                (billingState.customerId.isNotEmpty
                    ? billingState.customerDue
                    : 0.0);

            return BlocBuilder<ShopBloc, ShopState>(
              builder: (context, shopState) {
                String upiId = '';
                String shopName = 'Shop';

                if (shopState is ShopLoaded) {
                  upiId = shopState.shop.upiId;
                  shopName = shopState.shop.name;
                }

                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                          20,
                          10,
                          20,
                          180 +
                              MediaQuery.of(context).viewInsets.bottom +
                              MediaQuery.of(context).padding.bottom),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (billingState.customerId.isNotEmpty)
                            _buildCustomerTag(billingState.customerName),
                          const SizedBox(height: 16),
                          _buildReceiptCard(billingState),
                          if (billingState.customerId.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _buildPaymentOptionsCard(grandTotal,
                                billingState.customerName),
                          ] else ...[
                            const SizedBox(height: 24),
                            _buildGuestPaymentMethodSelector(),
                          ],
                          if (upiId.isNotEmpty && _paymentMethod == 'upi') ...[
                            const SizedBox(height: 24),
                            _buildQRCodeSection(upiId, shopName),
                          ],
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _buildBottomActions(billingState,
                          shopState is ShopLoaded ? shopState.shop : null,
                          grandTotal),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomerTag(String name) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.person_rounded,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                'Billing to: $name',
                style:  TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard(BillingState billingState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child:  Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Order Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: billingState.cartItems.length,
            separatorBuilder: (context, index) =>
                Divider(color: Colors.grey.shade100, height: 1),
            itemBuilder: (context, index) {
              final item = billingState.cartItems[index];
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Icon(Icons.inventory_2_rounded,
                            size: 20, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style:  TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.sp,
                              color: const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rs ${item.product.price.toStringAsFixed(2)} x ${_formatCheckoutQty(item)}',
                            style:  TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rs ${item.total.toStringAsFixed(2)}',
                      style:  TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.sp,
                        color: const Color(0xFF0F172A),
                      ),
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
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: Colors.grey.shade200,
                  ),
                ),
              ),
            ),
          ),
          // ── Amount summary ───────────────────────────────────────────
          Builder(builder: (context) {
            final subTotal = billingState.totalAmount;
            final prevDue = billingState.customerDue;
            final hasDue =
                billingState.customerId.isNotEmpty && prevDue > 0;
            final grandTotal = subTotal + (hasDue ? prevDue : 0);

            // GST info
            final settingsBox = HiveDatabase.settingsBox;
            final gstEnabled = settingsBox.get('gst_enabled', defaultValue: false) as bool;
            final gstRate = gstEnabled
                ? (settingsBox.get('gst_rate', defaultValue: 0.0) as num).toDouble()
                : 0.0;
            final bool showGst = gstEnabled && gstRate > 0;
            final taxableAmount = showGst ? subTotal / (1 + gstRate / 100) : 0.0;
            final totalTax = showGst ? subTotal - taxableAmount : 0.0;
            final halfRate = gstRate / 2;
            final cgst = totalTax / 2;
            final sgst = totalTax / 2;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  // GST breakdown rows
                  if (showGst) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TAXABLE AMOUNT',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Rs ${taxableAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CGST @ ${halfRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Rs ${cgst.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SGST @ ${halfRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Rs ${sgst.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),
                  ],
                  // Sub Total row — only shown when there is a previous due
                  if (hasDue) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text(
                        'SUB TOTAL',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                          fontSize: 10.sp,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Rs ${subTotal.toStringAsFixed(2)}',
                        style:  TextStyle(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                  ],
                  // Previous due row — only for customer bills with existing due
                  if (hasDue) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children:  [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Text(
                                'PREV. DUE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFD97706),
                                  fontSize: 10.sp,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '+ Rs ${prevDue.toStringAsFixed(2)}',
                            style:  TextStyle(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD97706),
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ],
                  const SizedBox(height: 10),
                  // Grand Total / Total Amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hasDue ? 'GRAND TOTAL' : 'TOTAL AMOUNT',
                        style:  TextStyle(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                          fontSize: 13.sp,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Rs ${grandTotal.toStringAsFixed(2)}',
                        style:  TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                          fontSize: 22.sp,
                        ),
                      ),
                    ],
                  ),
                  // GST inclusive note
                  if (showGst) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Incl. GST ${gstRate.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionsCard(double totalAmount, String customerName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
          'Payment Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16.sp,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(
                'Amount Will Pay Now',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.sp,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountPaidController,
                focusNode: _amountFocusNode,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofillHints: const [],
                style:  TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18.sp,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  prefixText: 'Rs ',
                  prefixStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Color(0xFF0F172A),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onChanged: (val) {
                  setState(() {
                    _qrAmount = double.tryParse(val) ?? 0.0;
                  });
                },
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final paid = _parseWillingToPay(totalAmount);
                  final due = totalAmount - paid;
                  if (due > 0) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFF97316), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Remaining Rs ${due.toStringAsFixed(2)} will be added as due to $customerName.',
                              style: const TextStyle(
                                color: Color(0xFFC2410C),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 20),
               Text(
                'Payment Method',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.sp,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildPaymentMethodPill('Cash', Icons.money_rounded, 'cash'),
                  const SizedBox(width: 10),
                  _buildPaymentMethodPill(
                      'UPI', Icons.qr_code_scanner_rounded, 'upi'),
                  const SizedBox(width: 10),
                  _buildPaymentMethodPill(
                      'Card', Icons.credit_card_rounded, 'card'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Payment method selector shown for guest (non-customer) checkout.
  /// Tapping UPI reveals the QR code section.
  Widget _buildGuestPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
              _buildPaymentMethodPill('Cash', Icons.money_rounded, 'cash'),
              const SizedBox(width: 10),
              _buildPaymentMethodPill(
                  'UPI', Icons.qr_code_scanner_rounded, 'upi'),
              const SizedBox(width: 10),
              _buildPaymentMethodPill(
                  'Card', Icons.credit_card_rounded, 'card'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodPill(String label, IconData icon, String value) {
    final isSelected = _paymentMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _paymentMethod = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRCodeSection(String upiId, String shopName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pay via UPI',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Rs ${_qrAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF15803D),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SizedBox(
              width: 180,
              height: 180,
              child: PrettyQrView.data(
                data:
                    'upi://pay?pa=$upiId&pn=$shopName&am=${_qrAmount.toStringAsFixed(2)}&cu=INR',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(
      BillingState billingState, dynamic shop, double grandTotal) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isFinishing
                    ? null
                    : () {
                    final paid = billingState.customerId.isNotEmpty
                      ? _validatedCustomerAmountToPay(grandTotal)
                      : billingState.totalAmount;
                    if (paid == null) return;

                        setState(() => _isFinishing = true);
                        context.read<BillingBloc>().add(
                              FinishTransactionEvent(
                                  amountPaid: paid,
                                  paymentMethod: _paymentMethod),
                            );
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side:
                      const BorderSide(color: AppTheme.primaryColor, width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.05),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Text(
                      'Finish without Receipt',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.sp ,
                      ),
                    ),
                    if (_isFinishing) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isPrinting || billingState.isPrinting)
                    ? null
                    : () {
                        if (shop != null) {
                      final paid = billingState.customerId.isNotEmpty
                        ? _validatedCustomerAmountToPay(grandTotal)
                        : billingState.totalAmount;
                      if (paid == null) return;

                          setState(() => _isPrinting = true);
                          context.read<BillingBloc>().add(PrintReceiptEvent(
                                shopName: shop.name,
                                address1: shop.addressLine1,
                                address2: shop.addressLine2,
                                phone: shop.phoneNumber,
                                footer: shop.footerText,
                                amountPaid: paid,
                                paymentMethod: _paymentMethod,
                                upiId: shop.upiId,
                              ));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Shop details not loaded'),
                                backgroundColor: Colors.red),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: billingState.isPrinting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3),
                      )
                    :  Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.print_rounded, size: 18.h),
                          SizedBox(width: 8.w),
                          Text(
                            'Print Receipt & Finish',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.sp,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
