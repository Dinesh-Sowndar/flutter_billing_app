import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/service_locator.dart' as di;
import '../../../billing/data/models/transaction_model.dart';
import '../../../product/data/models/product_model.dart';
import '../../domain/entities/customer_entity.dart';

// Lightweight cart item passed from CustomerPurchasePage
class CustomerCartItem {
  final ProductModel product;
  final int quantity;
  CustomerCartItem({required this.product, required this.quantity});
  double get total => product.price * quantity;
}

class CustomerReviewPage extends StatefulWidget {
  final CustomerEntity customer;
  final List<CustomerCartItem> items;

  const CustomerReviewPage({
    super.key,
    required this.customer,
    required this.items,
  });

  @override
  State<CustomerReviewPage> createState() => _CustomerReviewPageState();
}

class _CustomerReviewPageState extends State<CustomerReviewPage> {
  bool _isSaving = false;

  double get _total =>
      widget.items.fold(0.0, (sum, item) => sum + item.total);

  Future<void> _confirmPurchase() async {
    setState(() => _isSaving = true);

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final syncService = di.sl<SyncService>();

    final transaction = TransactionModel(
      id: const Uuid().v4(),
      date: DateTime.now(),
      totalAmount: _total,
      userId: userId,
      customerId: widget.customer.id,
      customerName: widget.customer.name,
      pendingSync: !syncService.isOnline,
      items: widget.items
          .map((c) => TransactionItemModel(
                productId: c.product.id,
                productName: c.product.name,
                price: c.product.price,
                quantity: c.quantity,
                total: c.total,
              ))
          .toList(),
    );

    await HiveDatabase.transactionBox.put(transaction.id, transaction);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Purchase of ₹${_total.toStringAsFixed(2)} saved for ${widget.customer.name}'
          '${syncService.isOnline ? '' : '  (will sync when online)'}',
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      // Pop back to customer list clearing the scanner too
      context.go('/customers');
    }
  }

  @override
  Widget build(BuildContext context) {
    final upiId = ''; // Could be wired up from ShopBloc if desired

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Review Order',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Customer info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.25),
                          child: Text(
                            widget.customer.name.isNotEmpty
                                ? widget.customer.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.customer.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17)),
                            const SizedBox(height: 2),
                            Text(widget.customer.phone,
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13)),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${widget.items.length} item(s)',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12)),
                            Text(
                              '₹${_total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Order summary receipt card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  color: Color(0xFF6C63FF), size: 20),
                              SizedBox(width: 8),
                              Text('Order Summary',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF6C63FF))),
                            ],
                          ),
                        ),
                        // Items table
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(1.2),
                            },
                            children: [
                              // Header row
                              TableRow(children: [
                                _headerCell('Item', TextAlign.left),
                                _headerCell('Qty', TextAlign.center),
                                _headerCell('Total', TextAlign.right),
                              ]),
                              // Data rows
                              ...widget.items.map((item) => TableRow(
                                    children: [
                                      _dataCell(item.product.name,
                                          TextAlign.left),
                                      _dataCell('${item.quantity}',
                                          TextAlign.center),
                                      _dataCell(
                                          '₹${item.total.toStringAsFixed(2)}',
                                          TextAlign.right,
                                          bold: true),
                                    ],
                                  )),
                            ],
                          ),
                        ),
                        // Divider
                        const Divider(
                            indent: 20, endIndent: 20, height: 1),
                        // Total row
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                      color: Color(0xFF94A3B8))),
                              Text(
                                '₹${_total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // UPI QR (optional placeholder — can wire ShopBloc later)
                  if (upiId.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text('Pay via UPI',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B))),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: PrettyQrView.data(
                              data:
                                  'upi://pay?pa=$upiId&pn=${widget.customer.name}&am=${_total.toStringAsFixed(2)}&cu=INR',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),

          // Fixed bottom confirm button
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _confirmPurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 22),
                label: Text(
                  _isSaving ? 'Saving…' : 'Confirm Purchase',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _dataCell(String text, TextAlign align, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 15,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          color: const Color(0xFF1E293B),
        ),
      ),
    );
  }
}
