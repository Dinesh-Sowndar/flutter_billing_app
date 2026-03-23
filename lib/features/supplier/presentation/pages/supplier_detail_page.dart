import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/supplier_entity.dart';
import '../../domain/entities/supplier_purchase_entity.dart';
import '../../domain/usecases/supplier_usecases.dart';
import '../bloc/supplier_bloc.dart';
import '../bloc/supplier_event.dart';
import '../bloc/supplier_purchase_bloc.dart';
import '../bloc/supplier_purchase_event.dart';
import '../bloc/supplier_purchase_state.dart';
import '../../../../core/service_locator.dart' as di;

class SupplierDetailPage extends StatelessWidget {
  final SupplierEntity supplier;
  const SupplierDetailPage({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<SupplierBloc>()),
        BlocProvider(
          create: (_) => di.sl<SupplierPurchaseBloc>()
            ..add(LoadSupplierPurchasesEvent(supplier.id)),
        ),
      ],
      child: _SupplierDetailView(supplier: supplier),
    );
  }
}

class _SupplierDetailView extends StatefulWidget {
  final SupplierEntity supplier;
  const _SupplierDetailView({required this.supplier});

  @override
  State<_SupplierDetailView> createState() => _SupplierDetailViewState();
}

class _SupplierDetailViewState extends State<_SupplierDetailView> {
  late SupplierEntity _supplier;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
  }

  void _showPaymentSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Record Payment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Current due: ₹${_supplier.balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Amount Paid',
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final amount = double.tryParse(ctrl.text) ?? 0;
                    if (amount <= 0) return;
                    final newBalance = (_supplier.balance - amount).clamp(0, double.infinity).toDouble();
                    final updated = _supplier.copyWith(balance: newBalance);
                    setState(() => _supplier = updated);
                    context.read<SupplierBloc>().add(UpdateSupplierEvent(updated));
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('₹${amount.toStringAsFixed(2)} payment recorded'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    );
                  },
                  child: const Text(
                    'Record Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showPurchaseDetail(BuildContext context, SupplierPurchaseEntity p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Purchase Details',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A)),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd MMM yyyy').format(p.date),
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    ...p.items.map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Color(0xFF1E293B))),
                                    const SizedBox(height: 3),
                                    Text(
                                        '${item.quantity} ${item.unit} × ₹${item.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${item.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        )),
                    const Divider(height: 24),
                    _detailRow('Total', '₹${p.totalAmount.toStringAsFixed(2)}', bold: true),
                    const SizedBox(height: 6),
                    _detailRow('Paid', '₹${p.amountPaid.toStringAsFixed(2)}',
                        valueColor: const Color(0xFF16A34A)),
                    const SizedBox(height: 6),
                    _detailRow('Due', '₹${p.dueAmount.toStringAsFixed(2)}',
                        valueColor: p.dueAmount > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF16A34A),
                        bold: true),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500)),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDue = _supplier.balance > 0;
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
        title: Text(
          _supplier.name,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        titleSpacing: 8,
      ),
      body: Column(
        children: [
          // Header card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _supplier.name.isNotEmpty
                                ? _supplier.name[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_supplier.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 3),
                            Text(
                              _supplier.phone.isEmpty
                                  ? 'No phone'
                                  : _supplier.phone,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasDue ? 'Total Due' : 'Balance',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${_supplier.balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasDue)
                          TextButton.icon(
                            onPressed: _showPaymentSheet,
                            icon: const Icon(Icons.payment_rounded,
                                size: 16, color: Colors.white),
                            label: const Text('Record Payment',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Action button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await context.push(
                      '/suppliers/${_supplier.id}/purchase',
                      extra: _supplier);
                  if (!mounted) return;

                  // Reload purchases list
                  context
                      .read<SupplierPurchaseBloc>()
                      .add(LoadSupplierPurchasesEvent(_supplier.id));

                  // Reload supplier to get updated due balance from Hive
                  final updated = await di.sl<GetSupplierByIdUseCase>()(
                      _supplier.id);
                  if (mounted && updated != null) {
                    setState(() => _supplier = updated);
                  }
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text(
                  'Record Purchase',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Transactions list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PURCHASE HISTORY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BlocBuilder<SupplierPurchaseBloc, SupplierPurchaseState>(
              builder: (context, state) {
                if (state.status == SupplierPurchaseStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.purchases.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'No purchases yet',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: state.purchases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = state.purchases[i];
                    return GestureDetector(
                      onTap: () => _showPurchaseDetail(context, p),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.grey.shade100, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.receipt_rounded,
                                  color: Color(0xFF8B5CF6), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${p.items.length} item${p.items.length != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    DateFormat('dd MMM yyyy, hh:mm a')
                                        .format(p.date),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${p.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                if (p.dueAmount > 0)
                                  Text(
                                    'Due ₹${p.dueAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  const Text(
                                    'Paid',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
