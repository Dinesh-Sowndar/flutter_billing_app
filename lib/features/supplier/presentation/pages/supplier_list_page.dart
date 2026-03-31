import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:billing_app/core/widgets/app_back_button.dart';
import '../../domain/entities/supplier_entity.dart';
import 'add_supplier_page.dart';
import '../bloc/supplier_bloc.dart';
import '../bloc/supplier_event.dart';
import '../bloc/supplier_state.dart';
import '../../../../core/service_locator.dart' as di;

class SupplierListPage extends StatelessWidget {
  const SupplierListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<SupplierBloc>()..add(const LoadSuppliersEvent()),
      child: const _SupplierListView(),
    );
  }
}

class _SupplierListView extends StatefulWidget {
  const _SupplierListView();

  @override
  State<_SupplierListView> createState() => _SupplierListViewState();
}

enum _SupplierFilter { all, dueOnly, clearOnly }

class _SupplierListViewState extends State<_SupplierListView> {
  static const Color _primary = Color(0xFF0F766E);
  static const Color _primaryDark = Color(0xFF115E59);
  static const Color _surface = Color(0xFFF1F5F9);
  static const Color _textPrimary = Color(0xFF0F172A);

  final TextEditingController _searchController = TextEditingController();
  _SupplierFilter _activeFilter = _SupplierFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SupplierEntity> _applyFilters(List<SupplierEntity> suppliers) {
    final query = _searchController.text.trim().toLowerCase();

    return suppliers.where((supplier) {
      final matchesQuery = query.isEmpty ||
          supplier.name.toLowerCase().contains(query) ||
          supplier.phone.toLowerCase().contains(query);

      final matchesStatus = switch (_activeFilter) {
        _SupplierFilter.all => true,
        _SupplierFilter.dueOnly => supplier.balance > 0,
        _SupplierFilter.clearOnly => supplier.balance <= 0,
      };

      return matchesQuery && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 4,
        leading: AppBackButton(onPressed: () => context.pop(), leftPadding: 0),
        title: const Text(
          'Suppliers',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 23,
            color: _textPrimary,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await AddSupplierPage.showSheet(context);
          if (context.mounted) {
            context.read<SupplierBloc>().add(const LoadSuppliersEvent());
          }
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Add Supplier',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<SupplierBloc, SupplierState>(
        builder: (context, state) {
          if (state.status == SupplierStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredSuppliers = _applyFilters(state.suppliers);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: _SummaryCard(suppliers: state.suppliers),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by supplier name or phone',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    _FilterChip(
                      selected: _activeFilter == _SupplierFilter.all,
                      label: 'All',
                      onTap: () =>
                          setState(() => _activeFilter = _SupplierFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      selected: _activeFilter == _SupplierFilter.dueOnly,
                      label: 'With Due',
                      onTap: () => setState(
                          () => _activeFilter = _SupplierFilter.dueOnly),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      selected: _activeFilter == _SupplierFilter.clearOnly,
                      label: 'Cleared',
                      onTap: () => setState(
                          () => _activeFilter = _SupplierFilter.clearOnly),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.suppliers.isEmpty
                    ? const _EmptyState()
                    : filteredSuppliers.isEmpty
                        ? const _NoResultsState()
                        : RefreshIndicator(
                            onRefresh: () async {
                              context
                                  .read<SupplierBloc>()
                                  .add(const LoadSuppliersEvent());
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: filteredSuppliers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final supplier = filteredSuppliers[index];
                                return _SupplierCard(supplier: supplier);
                              },
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<SupplierEntity> suppliers;

  const _SummaryCard({required this.suppliers});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0F766E);
    const primaryDark = Color(0xFF115E59);

    final dueCount = suppliers.where((s) => s.balance > 0).length;
    final totalDue = suppliers.fold<double>(0.0, (sum, s) => sum + s.balance);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primaryDark],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${suppliers.length} supplier${suppliers.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Outstanding: Rs ${totalDue.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$dueCount with pending due',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final SupplierEntity supplier;

  const _SupplierCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final hasDue = supplier.balance > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await context.push('/suppliers/${supplier.id}', extra: supplier);
        if (context.mounted) {
          context.read<SupplierBloc>().add(const LoadSuppliersEvent());
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFCCFBF1),
              child: Text(
                supplier.name.isEmpty ? 'S' : supplier.name[0].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F766E),
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    supplier.phone.isEmpty ? 'Phone not added' : supplier.phone,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: supplier.pendingSync
                              ? const Color(0xFFD97706)
                              : const Color(0xFF059669),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        supplier.pendingSync ? 'Not synced' : 'Synced',
                        style: TextStyle(
                          fontSize: 11,
                          color: supplier.pendingSync
                              ? const Color(0xFFD97706)
                              : const Color(0xFF059669),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasDue
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hasDue
                        ? 'Rs ${supplier.balance.toStringAsFixed(2)}'
                        : 'Cleared',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: hasDue
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF059669),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF134E4A) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF134E4A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.groups_rounded, size: 54, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text(
            'No suppliers yet',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.search_off_rounded, size: 54, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text(
            'No suppliers match this filter',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
