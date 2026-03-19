import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/service_locator.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/repositories/billing_repository.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final BillingRepository _billingRepository = sl<BillingRepository>();
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];

  String _selectedFilter = 'This Month';
  DateTimeRange? _customRange;

  final List<String> _filters = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
    'Custom'
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    sl<SyncService>().onSyncComplete.stream.listen((_) {
      if (mounted) {
        _loadTransactions();
      }
    });
  }

  void _loadTransactions() {
    try {
      final transactions = _billingRepository.getAllTransactions();
      // Sort DESC
      transactions.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _allTransactions = transactions;
      });
      _applyFilter();
    } catch (e) {
      // Ignore
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    List<TransactionModel> filtered = [];

    switch (_selectedFilter) {
      case 'Today':
        filtered = _allTransactions
            .where((t) =>
                t.date.isAfter(startOfDay) ||
                t.date.isAtSameMomentAs(startOfDay))
            .toList();
        break;
      case 'This Week':
        final daysSinceMonday = now.weekday - 1;
        final startOfWeek =
            startOfDay.subtract(Duration(days: daysSinceMonday));
        filtered = _allTransactions
            .where((t) =>
                t.date.isAfter(startOfWeek) ||
                t.date.isAtSameMomentAs(startOfWeek))
            .toList();
        break;
      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        filtered = _allTransactions
            .where((t) =>
                t.date.isAfter(startOfMonth) ||
                t.date.isAtSameMomentAs(startOfMonth))
            .toList();
        break;
      case 'This Year':
        final startOfYear = DateTime(now.year, 1, 1);
        filtered = _allTransactions
            .where((t) =>
                t.date.isAfter(startOfYear) ||
                t.date.isAtSameMomentAs(startOfYear))
            .toList();
        break;
      case 'Custom':
        if (_customRange != null) {
          final start = _customRange!.start;
          // End of day
          final end = DateTime(_customRange!.end.year, _customRange!.end.month,
              _customRange!.end.day, 23, 59, 59);
          filtered = _allTransactions
              .where((t) =>
                  t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
                  t.date.isBefore(end.add(const Duration(seconds: 1))))
              .toList();
        } else {
          filtered = List.from(_allTransactions);
        }
        break;
      default:
        filtered = List.from(_allTransactions);
    }

    setState(() {
      _filteredTransactions = filtered;
    });
  }

  Future<void> _selectCustomRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFilter = 'Custom';
        _customRange = picked;
      });
      _applyFilter();
    } else {
      // Revert if they cancelled Custom range selection and previously had none
      if (_customRange == null) {
        setState(() {
          _selectedFilter = 'This Month';
        });
        _applyFilter();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Summary metrics for the selected range
    final totalSales = _filteredTransactions.fold<double>(
        0.0, (sum, t) => sum + t.totalAmount);
    final totalCollected = _filteredTransactions.fold<double>(
      0.0,
      (sum, t) => sum + ((t.amountPaid < 0 ? 0.0 : t.amountPaid)),
    );
    final totalOutstanding = _filteredTransactions.fold<double>(0.0, (sum, t) {
      final isPaymentOnly = t.items.isEmpty && t.amountPaid > 0;
      if (isPaymentOnly) {
        return sum - t.amountPaid;
      }

      final paidAtSale = t.amountPaid.clamp(0.0, t.totalAmount).toDouble();
      final due = t.totalAmount - paidAtSale;
      return sum + (due > 0 ? due : 0.0);
    });
    final safeTotalOutstanding = totalOutstanding < 0 ? 0.0 : totalOutstanding;

    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text(
          'All Transactions',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 14 : 16,
                vertical: 8,
              ),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter == 'Custom' && _customRange != null && isSelected
                          ? '${DateFormat('MMM d').format(_customRange!.start)} - ${DateFormat('MMM d').format(_customRange!.end)}'
                          : filter,
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : const Color(0xFF64748B),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (filter == 'Custom') {
                        _selectCustomRange();
                      } else {
                        setState(() {
                          _selectedFilter = filter;
                        });
                        _applyFilter();
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: AppTheme.primaryColor,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: EdgeInsets.fromLTRB(
                isCompact ? 14 : 20, 8, isCompact ? 14 : 20, 16),
            padding: EdgeInsets.all(isCompact ? 18 : 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), AppTheme.primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.analytics_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Summary (${_filteredTransactions.length} records)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildMetricRow('Total Billed', totalSales, Colors.white),
                const SizedBox(height: 8),
                _buildMetricRow('Amount Paid', totalCollected, Colors.white),
                const SizedBox(height: 8),
                _buildMetricRow(
                    'Total Pending Amount', safeTotalOutstanding, Colors.white),
              ],
            ),
          ),
          Expanded(
            child: _filteredTransactions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 48, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 12),
                        Text(
                          'No transactions found for this period.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        isCompact ? 14 : 20, 2, isCompact ? 14 : 20, 16),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final t = _filteredTransactions[index];
                      final isPaymentOnly = t.items.isEmpty && t.amountPaid > 0;
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          DateFormat('dd MMM yyyy, hh:mm a')
                                              .format(t.date),
                                          style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 11.5),
                                        ),
                                        if (t.pendingSync) ...[
                                          const SizedBox(width: 8),
                                          const Icon(Icons.cloud_off_rounded,
                                              size: 12,
                                              color: AppTheme.errorColor),
                                        ],
                                      ],
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
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, TransactionModel t) {
    final due = (t.totalAmount - t.amountPaid).clamp(0.0, double.infinity);
    final isPaymentOnly = t.items.isEmpty && t.amountPaid > 0;
    final balanceDue =
        isPaymentOnly ? _customerDueAfterTransaction(t) : due.toDouble();
    final totalDueAmount =
        isPaymentOnly ? (balanceDue + t.amountPaid) : t.totalAmount;

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

  double _customerDueAfterTransaction(TransactionModel selectedTx) {
    if (selectedTx.customerId.isEmpty) return 0.0;

    final customerTransactions = _allTransactions
        .where((t) => t.customerId == selectedTx.customerId)
        .toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.id.compareTo(b.id);
      });

    var runningDue = 0.0;
    for (final tx in customerTransactions) {
      final isPaymentOnly = tx.items.isEmpty && tx.amountPaid > 0;

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

  Widget _buildMetricRow(String label, double value, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: textColor.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        Text('₹${value.toStringAsFixed(2)}',
            style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
      ],
    );
  }
}
