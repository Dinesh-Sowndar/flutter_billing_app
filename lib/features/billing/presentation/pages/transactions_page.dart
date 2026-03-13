import 'dart:ui';
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
        filtered = _allTransactions.where((t) => t.date.isAfter(startOfDay) || t.date.isAtSameMomentAs(startOfDay)).toList();
        break;
      case 'This Week':
        final daysSinceMonday = now.weekday - 1;
        final startOfWeek = startOfDay.subtract(Duration(days: daysSinceMonday));
        filtered = _allTransactions.where((t) => t.date.isAfter(startOfWeek) || t.date.isAtSameMomentAs(startOfWeek)).toList();
        break;
      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        filtered = _allTransactions.where((t) => t.date.isAfter(startOfMonth) || t.date.isAtSameMomentAs(startOfMonth)).toList();
        break;
      case 'This Year':
        final startOfYear = DateTime(now.year, 1, 1);
        filtered = _allTransactions.where((t) => t.date.isAfter(startOfYear) || t.date.isAtSameMomentAs(startOfYear)).toList();
        break;
      case 'Custom':
        if (_customRange != null) {
          final start = _customRange!.start;
          // End of day
          final end = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59);
          filtered = _allTransactions.where((t) => t.date.isAfter(start.subtract(const Duration(seconds: 1))) && t.date.isBefore(end.add(const Duration(seconds: 1)))).toList();
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
      initialDateRange: _customRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
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
    // Total calculation for the current filter
    final totalSales = _filteredTransactions.fold<double>(0.0, (sum, t) => sum + t.totalAmount);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded,
              size: 32, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
                    backgroundColor: const Color(0xFFF1F5F9),
                    selectedColor: AppTheme.primaryColor,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                      )
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Total Summary Card
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), AppTheme.primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Sales (${_filteredTransactions.length})',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text('₹${totalSales.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
          
          // Transactions List
          Expanded(
            child: _filteredTransactions.isEmpty
                ? const Center(
                    child: Text('No transactions found for this period.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final t = _filteredTransactions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Center(
                                child: Icon(Icons.receipt_long_rounded,
                                    color: AppTheme.primaryColor.withValues(alpha: 0.8)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.items.length == 1
                                        ? '${t.items.length} item'
                                        : '${t.items.length} items',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy, hh:mm a').format(t.date),
                                        style: const TextStyle(
                                            color: Color(0xFF64748B), fontSize: 12),
                                      ),
                                      if (t.pendingSync) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.cloud_off_rounded, size: 12, color: AppTheme.errorColor),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${t.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      )
    );
  }
}
