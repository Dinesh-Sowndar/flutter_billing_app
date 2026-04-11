import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/service_locator.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../billing/data/models/transaction_model.dart';
import '../../../billing/domain/repositories/billing_repository.dart';
import '../../../shop/data/models/shop_model.dart';
import '../../domain/entities/customer_entity.dart';
import '../../data/models/customer_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'edit_customer_page.dart';
import '../bloc/customer_bloc.dart';
import '../bloc/customer_event.dart';

class CustomerDetailPage extends StatelessWidget {
  final CustomerEntity customer;
  const CustomerDetailPage({super.key, required this.customer});

  static const Color _accent = Color(0xFF1E3A8A);
  static const Color _accentDark = Color(0xFF312E81);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _ink = Color(0xFF1F2937);
  static const Color _accentSoft = Color(0xFFEEF2FF);
  static const Color _accentSoftAlt = Color(0xFFE0E7FF);

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    try {
      final launched = await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open dialer.')),
        );
      }
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone integration not ready. Restart the app once.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveDatabase.customerBox.listenable(),
      builder: (context, Box<CustomerModel> box, _) {
        final currentCustomerModel = box.get(customer.id);
        final currentCustomer = currentCustomerModel?.toEntity() ?? customer;

        return ValueListenableBuilder(
          valueListenable: HiveDatabase.transactionBox.listenable(),
          builder: (context, Box<TransactionModel> txBox, _) {
            final transactions = txBox.values
                .where((t) => t.customerId == currentCustomer.id)
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            final ledgerDue = currentCustomer.balance;

            final totalSpent = transactions.fold(0.0,
                (sum, t) => sum + (t.items.isNotEmpty ? t.totalAmount : 0));

            return Scaffold(
              backgroundColor: _surface,
              appBar: AppBar(
                title: Text(
                  'Customer Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20.sp,
                    color: _ink,
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                iconTheme: const IconThemeData(color: _ink),
                actions: [
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: _ink),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    elevation: 4,
                    offset: const Offset(0, 40),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'edit') {
                        EditCustomerPage.showSheet(context, currentCustomer)
                            .then((_) {
                          if (context.mounted) {
                            context
                                .read<CustomerBloc>()
                                .add(LoadCustomersEvent());
                          }
                        });
                      } else if (value == 'delete') {
                        _confirmDelete(context, currentCustomer);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _accentSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.edit_rounded,
                                  size: 16, color: _accent),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Edit',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 8),
                      PopupMenuItem(
                        value: 'delete',
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.delete_sweep_rounded,
                                  size: 16, color: Colors.red.shade400),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.red.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => context.push(
                  '/customers/${currentCustomer.id}/purchase',
                  extra: currentCustomer,
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(
                  'Add Bill',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      fontSize: 14.sp),
                ),
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              body: Column(
                children: [
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          _accent,
                          _accentDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64.w,
                          height: 64.h,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            currentCustomer.name.isNotEmpty
                                ? currentCustomer.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20.sp),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentCustomer.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18.sp,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (ledgerDue > 0)
                                    _headerActionButton(
                                      icon: Icons.payments_rounded,
                                      label: 'PAY NOW',
                                      onTap: () => _showPaymentDialog(
                                        context,
                                        currentCustomer,
                                        ledgerDue,
                                      ),
                                    ),
                                  _headerActionButton(
                                    icon: Icons.add_card_rounded,
                                    label: 'ADD DUE',
                                    onTap: () => _showAddDueDialog(
                                      context,
                                      currentCustomer,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: () => _makePhoneCall(
                                    context, currentCustomer.phone),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.call_rounded,
                                          size: 16, color: Colors.white70),
                                      const SizedBox(width: 6),
                                      Text(
                                        currentCustomer.phone,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${transactions.length} transaction${transactions.length == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: ledgerDue > 0
                                          ? _accentSoftAlt
                                          : _accentSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      ledgerDue > 0
                                          ? 'Due Rs ${ledgerDue.toStringAsFixed(0)}'
                                          : 'All Cleared',
                                      style: TextStyle(
                                        color: ledgerDue > 0
                                            ? _accentDark
                                            : _accent,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                            child: _buildStatCard('Total Spent', totalSpent,
                                Icons.shopping_bag_rounded, Colors.indigo)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDueBalanceCard(
                            context,
                            ledgerDue,
                            currentCustomer,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Transaction History Header ──────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          'Transaction History',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${transactions.length} entries',
                            style: TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Purchase history list
                  Expanded(
                    child: transactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      )
                                    ],
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded,
                                      size: 48, color: Color(0xFFCBD5E1)),
                                ),
                                const SizedBox(height: 16),
                                Text('No history yet',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF94A3B8))),
                                const SizedBox(height: 6),
                                const Text(
                                    'Tap "Add Bill" to create first entry',
                                    style: TextStyle(color: Color(0xFF94A3B8))),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              final tx = transactions[index];
                              final isPayment = _isPaymentOnlyTransaction(tx);
                              final isDueAdded = _isDueAdditionTransaction(tx);

                              if (isPayment) {
                                return _buildPaymentTile(context, tx);
                              }
                              if (isDueAdded) {
                                return _buildDueAddedTile(context, tx);
                              }

                              return _buildTransactionTile(context, tx);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, double amount, IconData icon, MaterialColor color) {
    final currencyFormat =
        NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color.shade600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: color.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Due Balance card with inline Pay Now button when due > 0.
  Widget _buildDueBalanceCard(
      BuildContext context, double due, CustomerEntity customer) {
    final currencyFormat =
        NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
    final color = due > 0 ? Colors.red : Colors.green;
    final hasDue = due > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasDue ? Colors.red.shade100 : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_balance_wallet_rounded,
                    size: 16, color: color.shade600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Due Balance',
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  currencyFormat.format(due),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: color.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: _accent,
                fontWeight: FontWeight.w900,
                fontSize: 12.sp,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, TransactionModel tx) {
    final billDue = (tx.totalAmount - tx.amountPaid.clamp(0.0, tx.totalAmount));
    final isPaid = billDue <= 0;
    final isPartial = billDue > 0 && tx.amountPaid > 0;
    final isUnpaid = !isPaid && !isPartial;
    final currencyFormat =
        NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
    final date = tx.date;

    // Left-border color
    final borderColor = isUnpaid
        ? Colors.red.shade400
        : isPartial
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return GestureDetector(
      onTap: () => _showTransactionDetail(context, tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Color bar + date column ──
              Container(
                width: 60,
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.06),
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(18)),
                  border: Border(
                    left: BorderSide(color: borderColor, width: 4),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd').format(date),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        color: borderColor,
                        height: 1,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: borderColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('yy').format(date),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: borderColor.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Main content ──
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time + status
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('hh:mm a').format(date),
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          _statusPill(
                            isUnpaid
                                ? 'Unpaid'
                                : isPartial
                                    ? 'Partial'
                                    : 'Settled',
                            isUnpaid
                                ? Colors.red.shade50
                                : isPartial
                                    ? const Color(0xFFFFF7ED)
                                    : const Color(0xFFECFDF5),
                            isUnpaid
                                ? Colors.red.shade700
                                : isPartial
                                    ? const Color(0xFFC2410C)
                                    : const Color(0xFF15803D),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Bill amount prominent
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormat.format(tx.totalAmount),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Paid ${currencyFormat.format(tx.amountPaid)}',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              if (billDue > 0)
                                Text(
                                  'Due ${currencyFormat.format(billDue)}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isPartial
                                        ? const Color(0xFFF59E0B)
                                        : Colors.red.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Items count + payment method
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${tx.items.length} item${tx.items.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accentSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_paymentIcon(tx.paymentMethod),
                                    size: 11, color: _accent),
                                const SizedBox(width: 4),
                                Text(
                                  tx.paymentMethod.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded,
                              size: 16, color: Color(0xFFCBD5E1)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDueAddedTile(BuildContext context, TransactionModel tx) {
    final currencyFormat =
        NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
    final date = tx.date;

    return GestureDetector(
      onTap: () => _showTransactionDetail(context, tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFDE68A)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(18)),
                  border: Border(
                    left: BorderSide(color: Color(0xFFF59E0B), width: 4),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd').format(date),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFB45309),
                        height: 1,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB45309),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('hh:mm a').format(date),
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          _statusPill(
                            'Due Added',
                            const Color(0xFFFFF7ED),
                            const Color(0xFFC2410C),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+${currencyFormat.format(tx.totalAmount)}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFC2410C),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Manual Due Entry',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accentSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _paymentIcon(tx.paymentMethod),
                                  size: 11,
                                  color: _accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _paymentMethodLabel(tx.paymentMethod),
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded,
                              size: 16, color: Color(0xFFCBD5E1)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTile(BuildContext context, TransactionModel tx) {
    final currencyFormat =
        NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
    final date = tx.date;

    return GestureDetector(
      onTap: () => _showTransactionDetail(context, tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFBBF7D0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Green bar + date
              Container(
                width: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(18)),
                  border: Border(
                    left: BorderSide(color: Color(0xFF22C55E), width: 4),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd').format(date),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF15803D),
                        height: 1,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF22C55E).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF16A34A), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Payment Received',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.sp,
                                color: Color(0xFF14532D),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('hh:mm a').format(date),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Color(0xFF4ADE80),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+ ${currencyFormat.format(tx.amountPaid)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16.sp,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          Text(
                            'Due cleared',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4ADE80),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ─── Transaction Detail Bottom Sheet ──────────────────────────────────────
  void _showTransactionDetail(BuildContext context, TransactionModel tx) {
    final cf = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
    final cf2 = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);
    final isPayment = _isPaymentOnlyTransaction(tx);
    final isDueAdded = _isDueAdditionTransaction(tx);
    final billDue = (tx.totalAmount - tx.amountPaid.clamp(0.0, tx.totalAmount));
    final isSettled = billDue <= 0;
    final isPartial = billDue > 0 && tx.amountPaid > 0;

    // Color theme for this transaction
    final headerGrad = isPayment
      ? [const Color(0xFF22C55E), const Color(0xFF15803D)]
      : isDueAdded
        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
        : isSettled
          ? [const Color(0xFF10B981), const Color(0xFF059669)]
          : isPartial
            ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
            : [const Color(0xFFEF4444), const Color(0xFFDC2626)];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // ── Gradient header ───────────────────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: headerGrad,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: headerGrad[0].withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPayment
                          ? Icons.check_circle_rounded
                          : isDueAdded
                              ? Icons.add_card_rounded
                              : Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPayment
                              ? 'Payment Received'
                              : isDueAdded
                                  ? 'Due Added'
                                  : 'Bill Receipt',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.sp,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM yyyy  •  hh:mm a').format(tx.date),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Big amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isPayment
                            ? '+${cf.format(tx.amountPaid)}'
                            : isDueAdded
                                ? '+${cf.format(tx.totalAmount)}'
                                : cf.format(tx.totalAmount),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16.sp,
                        ),
                      ),
                      if (!isPayment && !isDueAdded)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isSettled
                                ? 'Settled'
                                : isPartial
                                    ? 'Partial'
                                    : 'Unpaid',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────────────
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (isPayment) ...[
                    // Payment detail card
                    _detailCard([
                      _cardRow(
                        icon: Icons.check_circle_rounded,
                        iconColor: const Color(0xFF10B981),
                        label: 'Amount Paid',
                        value: cf2.format(tx.amountPaid),
                        valueColor: const Color(0xFF10B981),
                        bold: true,
                        large: true,
                      ),
                      _cardDivider(),
                      _cardRow(
                        icon: Icons.category_rounded,
                        iconColor: const Color(0xFF94A3B8),
                        label: 'Transaction Type',
                        value: 'Due Payment',
                      ),
                      _cardRow(
                        icon: Icons.calendar_today_rounded,
                        iconColor: const Color(0xFF94A3B8),
                        label: 'Date & Time',
                        value:
                            DateFormat('dd MMM yyyy, hh:mm a').format(tx.date),
                      ),
                    ]),
                  ] else if (isDueAdded) ...[
                    _detailCard([
                      _cardRow(
                        icon: Icons.add_card_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        label: 'Due Added',
                        value: cf2.format(tx.totalAmount),
                        valueColor: const Color(0xFFC2410C),
                        bold: true,
                        large: true,
                      ),
                      _cardDivider(),
                      _cardRow(
                        icon: Icons.category_rounded,
                        iconColor: const Color(0xFF94A3B8),
                        label: 'Transaction Type',
                        value: 'Due Added Manually',
                      ),
                      _cardRow(
                        icon: Icons.calendar_today_rounded,
                        iconColor: const Color(0xFF94A3B8),
                        label: 'Date & Time',
                        value:
                            DateFormat('dd MMM yyyy, hh:mm a').format(tx.date),
                      ),
                    ]),
                  ] else ...[
                    // ── Items section ─────────────────────────────────────
                    if (tx.items.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_rounded,
                                size: 16, color: _accent),
                            const SizedBox(width: 6),
                            Text(
                              '${tx.items.length} Item${tx.items.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ...List.generate(tx.items.length, (i) {
                              final item = tx.items[i];
                              final isLast = i == tx.items.length - 1;
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color:
                                                _accent.withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.inventory_2_rounded,
                                            size: 18,
                                            color: _accent,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.productName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: _ink,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Rs ${item.price.toStringAsFixed(0)}  ×  ${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF94A3B8),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          'Rs ${item.total.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: _ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isLast)
                                    Divider(
                                      height: 1,
                                      indent: 62,
                                      color: Colors.grey.shade100,
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Financial summary ─────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.summarize_rounded,
                              size: 16, color: _accent),
                          const SizedBox(width: 6),
                          const Text(
                            'Summary',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _detailCard([
                      // GST breakdown
                      if (tx.gstRate > 0) ...[
                        Builder(builder: (_) {
                          final taxable =
                              tx.totalAmount / (1 + tx.gstRate / 100);
                          final halfRate = tx.gstRate / 2;
                          return Column(
                            children: [
                              _cardRow(
                                icon: Icons.receipt_outlined,
                                iconColor: const Color(0xFF94A3B8),
                                label: 'Taxable Amount',
                                value: cf.format(taxable),
                                valueColor: const Color(0xFF64748B),
                              ),
                              _cardRow(
                                icon: Icons.percent_rounded,
                                iconColor: const Color(0xFF94A3B8),
                                label: 'CGST @ ${halfRate.toStringAsFixed(1)}%',
                                value: cf.format(tx.cgstAmount),
                                valueColor: const Color(0xFF64748B),
                              ),
                              _cardRow(
                                icon: Icons.percent_rounded,
                                iconColor: const Color(0xFF94A3B8),
                                label: 'SGST @ ${halfRate.toStringAsFixed(1)}%',
                                value: cf.format(tx.sgstAmount),
                                valueColor: const Color(0xFF64748B),
                              ),
                              _cardDivider(),
                            ],
                          );
                        }),
                      ],
                      _cardRow(
                        icon: Icons.receipt_long_rounded,
                        iconColor: _accent,
                        label: 'Bill Total',
                        value: cf.format(tx.totalAmount),
                        bold: true,
                        large: true,
                      ),
                      _cardDivider(),
                      _cardRow(
                        icon: Icons.check_circle_rounded,
                        iconColor: const Color(0xFF10B981),
                        label: 'Amount Paid',
                        value: cf.format(tx.amountPaid),
                        valueColor: const Color(0xFF10B981),
                        bold: tx.amountPaid >= tx.totalAmount,
                      ),
                      if (tx.amountPaid > tx.totalAmount)
                        _cardRow(
                          icon: Icons.arrow_circle_up_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          label: 'Prev Due Covered',
                          value:
                              '+${cf.format(tx.amountPaid - tx.totalAmount)}',
                          valueColor: const Color(0xFFF59E0B),
                        ),
                      if (billDue > 0)
                        _cardRow(
                          icon: Icons.warning_amber_rounded,
                          iconColor: Colors.red.shade400,
                          label: 'Due Amount',
                          value: cf.format(billDue),
                          valueColor: Colors.red.shade600,
                          bold: true,
                        ),
                      _cardDivider(),
                      _cardRow(
                        icon: _paymentIcon(tx.paymentMethod),
                        iconColor: _accent,
                        label: 'Payment Method',
                        value: _paymentMethodLabel(tx.paymentMethod),
                      ),
                    ]),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),

            // ── Print button ──────────────────────────────────────────────
            if (!isPayment && !isDueAdded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_accent, _accentDark],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _printTransaction(context, tx),
                      icon: const Icon(Icons.print_rounded, size: 20),
                      label: const Text('Print Bill',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: const SizedBox(height: 8),
              ),
            ],
            if (isPayment)
              const SafeArea(top: false, child: SizedBox(height: 16)),
            if (isDueAdded)
              const SafeArea(top: false, child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  /// A white rounded card wrapping a list of rows.
  Widget _detailCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _cardDivider() => Divider(
      height: 1, indent: 16, endIndent: 16, color: Colors.grey.shade100);

  Widget _cardRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
    bool bold = false,
    bool large = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                fontSize: 14.sp,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? _ink,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: large ? 16.sp : 14.sp,
            ),
          ),
        ],
      ),
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
      final isPaymentOnly = _isPaymentOnlyTransaction(tx);

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

  bool _isPaymentOnlyTransaction(TransactionModel tx) {
    return tx.items.isEmpty && tx.amountPaid > 0 && tx.totalAmount <= 0;
  }

  bool _isDueAdditionTransaction(TransactionModel tx) {
    return tx.items.isEmpty &&
        tx.amountPaid <= 0 &&
        tx.totalAmount > 0 &&
        tx.paymentMethod.toLowerCase() == 'due_addition';
  }

  String _paymentMethodLabel(String method) {
    if (method.toLowerCase() == 'due_addition') {
      return 'DUE ADD';
    }
    return method.toUpperCase();
  }

  Future<void> _printTransaction(
      BuildContext context, TransactionModel tx) async {
    final printerHelper = PrinterHelper();

    // Get shop info from Hive
    final shopBox = HiveDatabase.shopBox;
    final ShopModel? shop =
        shopBox.values.isNotEmpty ? shopBox.values.first : null;

    final shopName = shop?.name ?? 'Shop';
    final address1 = shop?.addressLine1 ?? '';
    final address2 = shop?.addressLine2 ?? '';
    final phone = shop?.phoneNumber ?? '';
    final footer = shop?.footerText ?? 'Thank you!';

    final items = tx.items
        .map((item) => {
              'name': item.productName,
              'qty': item.quantity,
              'price': item.price,
              'total': item.total,
            })
        .toList();

    try {
      await printerHelper.printReceipt(
        shopName: shopName,
        address1: address1,
        address2: address2,
        phone: phone,
        items: items,
        total: tx.totalAmount,
        prevDue: 0.0,
        amountPaid: tx.amountPaid,
        customerName: tx.customerName,
        paymentMethod: tx.paymentMethod,
        upiId: shop?.upiId ?? '',
        footer: footer,
        gstRate: tx.gstRate,
        cgstAmount: tx.cgstAmount,
        sgstAmount: tx.sgstAmount,
        gstNumber: tx.gstNumber,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Bill printed successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Print failed: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  IconData _paymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
        return Icons.qr_code_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      case 'due_addition':
        return Icons.add_card_rounded;
      default:
        return Icons.money_rounded;
    }
  }

  void _showAddDueDialog(BuildContext context, CustomerEntity customer) {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xFFFFF7ED),
                      child: Icon(Icons.add_card_rounded,
                          color: Color(0xFFC2410C), size: 26),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Add Due Balance',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Use this when adding due directly without creating a bill for ${customer.name}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Form(
                        key: formKey,
                        child: TextFormField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                          decoration: InputDecoration(
                            prefixText: 'Rs  ',
                            prefixStyle: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                            hintText: '0',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Color(0xFFD97706), width: 2),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Enter an amount';
                            }
                            final val = double.tryParse(v);
                            if (val == null || val <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  setState(() => isSaving = true);
                                  final amount =
                                      double.parse(amountController.text);

                                  final dueTx = TransactionModel(
                                    id: DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString(),
                                    customerId: customer.id,
                                    customerName: customer.name,
                                    items: const [],
                                    totalAmount: amount,
                                    amountPaid: 0.0,
                                    paymentMethod: 'due_addition',
                                    date: DateTime.now(),
                                    pendingSync: true,
                                  );
                                  await sl<BillingRepository>()
                                      .saveTransaction(dueTx);

                                  final existingModel =
                                      HiveDatabase.customerBox.get(customer.id);
                                  if (existingModel != null) {
                                    final updated = existingModel.copyWith(
                                      balance: existingModel.balance + amount,
                                      pendingSync: true,
                                    );
                                    await HiveDatabase.customerBox
                                        .put(customer.id, updated);
                                    unawaited(
                                        sl<SyncService>().pushCustomer(updated));
                                  }

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Due added: Rs ${amount.toStringAsFixed(0)}',
                                            ),
                                          ],
                                        ),
                                        backgroundColor:
                                            const Color(0xFFC2410C),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        margin: const EdgeInsets.all(16),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_rounded, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Confirm Add Due',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPaymentDialog(
      BuildContext context, CustomerEntity customer, double due) {
    final amountController =
        TextEditingController(text: due.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();
    final currencyFormat =
        NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          void selectAmount(double fraction) {
            final val = (due * fraction).roundToDouble();
            amountController.text = val.toStringAsFixed(0);
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Drag handle ─────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Header ──────────────────────────────────────────
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_accent, _accentDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.payments_rounded,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Record Payment',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customer.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Due badge ────────────────────────────────────────
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: Colors.red.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Outstanding: ${currencyFormat.format(due)}',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Quick-select chips ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(
                          'Quick select:',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _quickChip('25%', () => selectAmount(0.25), setState),
                        const SizedBox(width: 8),
                        _quickChip('50%', () => selectAmount(0.50), setState),
                        const SizedBox(width: 8),
                        _quickChip('Full', () => selectAmount(1.0), setState),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Amount input ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: formKey,
                      child: TextFormField(
                        controller: amountController,
                        autofocus: false,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                        decoration: InputDecoration(
                          prefixText: 'Rs  ',
                          prefixStyle: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                          hintText: '0',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: _accent, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.red.shade300),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter an amount';
                          final val = double.tryParse(v);
                          if (val == null || val <= 0)
                            return 'Enter a valid amount';
                          if (val > due) return 'Cannot exceed due amount';
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Confirm button ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: isSaving
                              ? null
                              : const LinearGradient(
                                  colors: [_accent, _accentDark],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color: isSaving ? Colors.grey.shade300 : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isSaving
                              ? []
                              : [
                                  BoxShadow(
                                    color: _accent.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setState(() => isSaving = true);
                                  final amount =
                                      double.parse(amountController.text);
                                  final paymentTx = TransactionModel(
                                    id: DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString(),
                                    customerId: customer.id,
                                    customerName: customer.name,
                                    items: [],
                                    totalAmount: 0.0,
                                    amountPaid: amount,
                                    paymentMethod: 'cash',
                                    date: DateTime.now(),
                                    pendingSync: true,
                                  );
                                  await sl<BillingRepository>()
                                      .saveTransaction(paymentTx);
                                  final existingModel =
                                      HiveDatabase.customerBox.get(customer.id);
                                  if (existingModel != null) {
                                    final newBalance =
                                        (existingModel.balance - amount)
                                            .clamp(0.0, double.infinity);
                                    final updated = existingModel.copyWith(
                                      balance: newBalance,
                                      pendingSync: true,
                                    );
                                    await HiveDatabase.customerBox
                                        .put(customer.id, updated);
                                    unawaited(sl<SyncService>()
                                        .pushCustomer(updated));
                                  }
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(Icons.check_circle_rounded,
                                                color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Text('Payment recorded!'),
                                          ],
                                        ),
                                        backgroundColor:
                                            const Color(0xFF10B981),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        margin: const EdgeInsets.all(16),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Confirm Payment',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),

                  // ── Cancel link ──────────────────────────────────────
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _quickChip(String label, VoidCallback onTap, StateSetter setState) {
    return GestureDetector(
      onTap: () {
        onTap();
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _accentSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _accentSoftAlt),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _accent,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CustomerEntity customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Delete Customer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to remove "${customer.name}"? All associated data will be deleted. This action cannot be undone.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context
                          .read<CustomerBloc>()
                          .add(DeleteCustomerEvent(customer.id));
                      Navigator.pop(ctx);
                      context.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
