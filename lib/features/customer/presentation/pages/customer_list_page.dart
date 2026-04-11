import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../domain/entities/customer_entity.dart';
import 'add_customer_page.dart';
import '../bloc/customer_bloc.dart';
import '../bloc/customer_event.dart';
import '../bloc/customer_state.dart';

class CustomerListPage extends StatefulWidget {
  final bool dueOnly;

  const CustomerListPage({super.key, this.dueOnly = false});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  static const Color _accent = Color(0xFF1E3A8A);
  static const Color _accentDark = Color(0xFF312E81);
  static const Color _accentSoft = Color(0xFFEEF2FF);

  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CustomerEntity> _filtered(List<CustomerEntity> customers) {
    final q = _searchQuery.trim();
    if (q.isEmpty) return customers;
    return customers
        .where((c) =>
            c.name.toLowerCase().contains(q.toLowerCase()) ||
            c.phone.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: context.canPop()
            ? AppBackButton(onPressed: () => context.pop())
            : null,
        titleSpacing: 6,
        title: Text(
          widget.dueOnly ? 'Customers with Due' : 'Customers',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20.sp,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: _accentSoft,
              child: const Icon(Icons.people_alt_rounded, color: _accent),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await AddCustomerPage.showSheet(context);
          if (context.mounted) {
            context.read<CustomerBloc>().add(LoadCustomersEvent());
          }
        },
        icon:  Icon(Icons.person_add_rounded,size: 20.w,),
        label: Text(
          'Add Customer',
          style: TextStyle(
              fontWeight: FontWeight.w700, letterSpacing: 0.5, fontSize: 14.sp),
        ),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: BlocBuilder<CustomerBloc, CustomerState>(
              builder: (context, state) {
                if (state.status == CustomerStatus.loading) {
                  return const Center(
                      child: CircularProgressIndicator(color: _accent));
                }

                if (state.status == CustomerStatus.error) {
                  return _buildErrorState(
                      state.error ?? 'Something went wrong');
                }

                return ValueListenableBuilder(
                  valueListenable: HiveDatabase.customerBox.listenable(),
                  builder: (context, customerBox, _) {
                    final freshCustomers = state.customers.map((c) {
                      final model = customerBox.get(c.id);
                      return model?.toEntity() ?? c;
                    }).toList();

                    final visibleCustomers =
                        _applyDueFilter(_filtered(freshCustomers));

                    if (visibleCustomers.isEmpty) {
                      return _buildEmptyState();
                    }

                    return _buildCustomerList(visibleCustomers);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search by name or phone...',
          hintStyle: TextStyle(
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.normal,
              fontSize: 14.sp),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon:
                      const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              size: 48,
              color: const Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty
                ? 'No customers found'
                : (widget.dueOnly ? 'No Due Customers' : 'No Customers Yet'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : (widget.dueOnly
                    ? 'All customer balances are settled'
                    : 'Add a customer to start tracking dues and purchases'),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<CustomerEntity> _applyDueFilter(List<CustomerEntity> customers) {
    if (!widget.dueOnly) return customers;
    return customers.where((c) => c.balance > 0).toList();
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.redAccent),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCustomerList(List<CustomerEntity> customers) {
    final currencyFormat =
        NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        final currentDue = customer.balance;
        final bool hasDue = currentDue > 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  context.push('/customers/${customer.id}', extra: customer),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _accent,
                            _accentDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        customer.name.isNotEmpty
                            ? customer.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20.sp,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  customer.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16.sp,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (customer.pendingSync) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.cloud_upload_outlined,
                                    size: 16, color: Colors.orange),
                              ]
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined,
                                  size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                customer.phone,
                                style: TextStyle(
                                  color: const Color(0xFF64748B),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Balance and Actions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (currentDue != 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasDue
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : _accentSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              hasDue
                                  ? 'Due: ${currencyFormat.format(currentDue)}'
                                  : 'Adv: ${currencyFormat.format(currentDue.abs())}',
                              style: TextStyle(
                                color: hasDue ? Colors.red.shade700 : _accent,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text('Settled',
                                style: TextStyle(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600)),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Quick Add Purchase button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => context.push(
                                    '/customers/${customer.id}/purchase',
                                    extra: customer),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _accent.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.point_of_sale_rounded,
                                          size: 16, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Bill',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
