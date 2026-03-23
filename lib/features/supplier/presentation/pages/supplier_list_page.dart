import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/supplier_entity.dart';
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

class _SupplierListView extends StatelessWidget {
  const _SupplierListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: Colors.black12,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                color: const Color(0xFF0F172A),
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ),
        title: const Text(
          'Suppliers',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        titleSpacing: 8,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/suppliers/add');
          if (context.mounted) {
            context.read<SupplierBloc>().add(const LoadSuppliersEvent());
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Supplier',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<SupplierBloc, SupplierState>(
        builder: (context, state) {
          if (state.status == SupplierStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 36,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No suppliers yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap "+ Add Supplier" to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: state.suppliers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final supplier = state.suppliers[index];
              return _SupplierCard(
                supplier: supplier,
                onDeleted: () {
                  context
                      .read<SupplierBloc>()
                      .add(DeleteSupplierEvent(supplier.id));
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final SupplierEntity supplier;
  final VoidCallback onDeleted;

  const _SupplierCard({required this.supplier, required this.onDeleted});

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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  supplier.name.isNotEmpty
                      ? supplier.name[0].toUpperCase()
                      : 'S',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    supplier.phone.isEmpty ? 'No phone' : supplier.phone,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: supplier.pendingSync
                              ? const Color(0xFFF59E0B) // amber — not synced
                              : const Color(0xFF10B981), // green — synced
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        supplier.pendingSync ? 'Not Synced' : 'Synced',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: supplier.pendingSync
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasDue)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '₹${supplier.balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Cleared',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                if (hasDue)
                  const Text(
                    'Due',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1), size: 22),
          ],
        ),
      ),
    );
  }
}
