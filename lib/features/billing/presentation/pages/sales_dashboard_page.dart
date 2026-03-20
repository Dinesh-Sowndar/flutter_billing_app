import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../billing/data/models/transaction_model.dart';
import '../../../customer/data/models/customer_model.dart';
import '../bloc/sales_bloc.dart';

class SalesDashboardPage extends StatefulWidget {
  const SalesDashboardPage({super.key});

  @override
  State<SalesDashboardPage> createState() => _SalesDashboardPageState();
}

class _SalesDashboardPageState extends State<SalesDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<SalesBloc>().add(LoadSalesEvent());
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final rowCardHeight = isCompact ? 140.0 : 152.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text(
          'Sales Dashboard',
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
        titleSpacing: 8,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Center(
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.pop(),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Color(0xFF0F172A)),
                ),
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<SalesBloc, SalesState>(
        builder: (context, state) {
          if (state.status == SalesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == SalesStatus.error) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  state.error ?? 'Unknown error',
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                isCompact ? 14 : 20, 8, isCompact ? 14 : 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: rowCardHeight,
                        child: _buildSalesCard(
                          'Today',
                          state.dailySales,
                          state.dailyPending,
                          AppTheme.primaryColor,
                          Icons.today_rounded,
                          compact: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: rowCardHeight,
                        child: _buildSalesCard(
                          'This Week',
                          state.weeklySales,
                          state.weeklyPending,
                          const Color(0xFF3B82F6),
                          Icons.date_range_rounded,
                          compact: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: rowCardHeight,
                        child: _buildSalesCard(
                          'This Month',
                          state.monthlySales,
                          state.monthlyPending,
                          const Color(0xFF8B5CF6),
                          Icons.calendar_month_rounded,
                          compact: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: rowCardHeight,
                        child: ValueListenableBuilder<Box<CustomerModel>>(
                          valueListenable:
                              HiveDatabase.customerBox.listenable(),
                          builder: (context, customerBox, _) {
                            return ValueListenableBuilder<Box<TransactionModel>>(
                              valueListenable:
                                  HiveDatabase.transactionBox.listenable(),
                              builder: (context, txBox, __) {
                                final customers = customerBox.values.toList();
                                final transactions = txBox.values.toList();
                                final dueCustomerCount = _countCustomersWithDue(
                                    customers, transactions);
                                final totalDue =
                                    _totalDueAmount(customers, transactions);

                                return _buildDueCustomersCard(
                                  dueCustomerCount,
                                  totalDue,
                                  compact: true,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/transactions'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (state.recentTransactions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.inbox_rounded,
                                  size: 48, color: Color(0xFFCBD5E1)),
                              SizedBox(height: 12),
                              Text(
                                'No transactions yet.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...state.recentTransactions.take(5).map((t) {
                          final isPaymentOnly =
                              t.items.isEmpty && t.amountPaid > 0;
                          return GestureDetector(
                            onTap: () => _showTransactionDetails(context, t),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
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
                                      color: isPaymentOnly
                                          ? const Color(0xFF10B981)
                                              .withValues(alpha: 0.1)
                                          : AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                        isPaymentOnly
                                            ? Icons.payments_rounded
                                            : Icons.shopping_bag_rounded,
                                        color: isPaymentOnly
                                            ? const Color(0xFF10B981)
                                            : AppTheme.primaryColor),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.customerName.isNotEmpty
                                              ? t.customerName
                                              : 'Guest Customer',
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
                                          isPaymentOnly
                                              ? 'Payment Received'
                                              : (t.items.length == 1
                                                  ? '1 Item'
                                                  : '${t.items.length} Items'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF94A3B8),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isPaymentOnly
                                        ? '+Rs ${t.amountPaid.toStringAsFixed(0)}'
                                        : 'Rs ${t.totalAmount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: isCompact ? 14 : 16,
                                      color: isPaymentOnly
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, dynamic t) {
    final due = (t.totalAmount - t.amountPaid).clamp(0.0, double.infinity);
    final isPaymentOnly = t.items.isEmpty && t.amountPaid > 0;
    final balanceDue = due.toDouble();
    final totalDueAmount = isPaymentOnly ? t.amountPaid : t.totalAmount;

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

  Widget _buildSalesCard(
      String title, double amount, double pending, Color color, IconData icon,
      {bool compact = false}) {
    final titleSize = compact ? 13.0 : 15.0;
    final amountSize = compact ? 22.0 : 28.0;
    final chipSize = compact ? 11.0 : 12.0;
    final iconSize = compact ? 20.0 : 24.0;

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 0.3,
                ),
              ),
              Container(
                padding: EdgeInsets.all(compact ? 6 : 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: iconSize),
              ),
            ],
          ),
          SizedBox(height: compact ? 16 : 20),
          Text(
            'Rs ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: amountSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.0,
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pending > 0
                      ? Icons.pending_actions_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: chipSize + 2,
                ),
                const SizedBox(width: 4),
                Text(
                  pending > 0
                      ? 'Rs ${pending.toStringAsFixed(0)} Due'
                      : 'Cleared',
                  style: TextStyle(
                    fontSize: chipSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueCustomersCard(int count, double totalDue,
      {bool compact = false}) {
    final titleSize = compact ? 13.0 : 15.0;
    final valueSize = compact ? 22.0 : 28.0;
    final detailSize = compact ? 11.0 : 12.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/customers', extra: {'dueOnly': true}),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFCA5A5).withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Due Customers',
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(compact ? 6 : 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.people_alt_rounded,
                      color: const Color(0xFFEF4444),
                      size: compact ? 20 : 24,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 16 : 20),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: compact ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: const Color(0xFFEF4444),
                      size: detailSize + 2,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Rs ${totalDue.toStringAsFixed(0)} Due',
                      style: TextStyle(
                        fontSize: detailSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _countCustomersWithDue(
    List<CustomerModel> customers,
    List<TransactionModel> transactions,
  ) {
    var count = 0;
    for (final customer in customers) {
      final customerTransactions =
          transactions.where((t) => t.customerId == customer.id).toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      if (_calculateCurrentDue(customerTransactions) > 0) {
        count++;
      }
    }
    return count;
  }

  double _totalDueAmount(
    List<CustomerModel> customers,
    List<TransactionModel> transactions,
  ) {
    var totalDue = 0.0;
    for (final customer in customers) {
      final customerTransactions =
          transactions.where((t) => t.customerId == customer.id).toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      final due = _calculateCurrentDue(customerTransactions);
      if (due > 0) {
        totalDue += due;
      }
    }
    return totalDue;
  }

  double _calculateCurrentDue(List<TransactionModel> transactions) {
    var totalDue = 0.0;
    for (final tx in transactions) {
      final isPaymentOnly = tx.items.isEmpty && tx.amountPaid > 0;
      if (isPaymentOnly) {
        totalDue -= tx.amountPaid;
      } else {
        final paidAtSale = tx.amountPaid.clamp(0.0, tx.totalAmount).toDouble();
        totalDue += (tx.totalAmount - paidAtSale);
      }
    }
    return totalDue;
  }
}
