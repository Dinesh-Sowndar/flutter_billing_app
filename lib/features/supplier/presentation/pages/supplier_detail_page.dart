import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:billing_app/core/widgets/app_back_button.dart';
import '../../../../core/data/hive_database.dart';
import '../../domain/entities/supplier_entity.dart';
import '../../domain/entities/supplier_purchase_entity.dart';
import '../../domain/usecases/supplier_usecases.dart';
import '../../domain/usecases/supplier_purchase_usecases.dart';
import '../bloc/supplier_purchase_bloc.dart';
import '../bloc/supplier_purchase_event.dart';
import '../bloc/supplier_purchase_state.dart';
import '../../../../core/service_locator.dart' as di;
import '../../../../core/utils/printer_helper.dart';
import '../../../shop/data/models/shop_model.dart';

class SupplierDetailPage extends StatelessWidget {
  final SupplierEntity supplier;
  const SupplierDetailPage({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<SupplierPurchaseBloc>()
        ..add(LoadSupplierPurchasesEvent(supplier.id)),
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
  static const Color _primary = Color(0xFF0F766E);
  static const Color _primaryDark = Color(0xFF115E59);
  static const Color _surface = Color(0xFFF1F5F9);

  late SupplierEntity _supplier;
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
  }

  void _showPaymentSheet() {
    final parentContext = context;
    final formKey = GlobalKey<FormState>();
    final amountController =
        TextEditingController(text: _supplier.balance.toStringAsFixed(0));
    final currencyFormat =
        NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0, locale: 'en_IN');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          void selectAmount(double fraction) {
            final val = (_supplier.balance * fraction).roundToDouble();
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
                        colors: [_primary, _primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.payments_rounded,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Record Payment',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _supplier.name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Due badge ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: _primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded,
                            size: 14, color: _primary),
                        const SizedBox(width: 6),
                        Text(
                          'Outstanding: ${currencyFormat.format(_supplier.balance)}',
                          style: const TextStyle(
                            color: _primaryDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
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
                        const Text(
                          'Quick select:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildQuickChip(
                            '25%', () => selectAmount(0.25), setSheetState),
                        const SizedBox(width: 8),
                        _buildQuickChip(
                            '50%', () => selectAmount(0.50), setSheetState),
                        const SizedBox(width: 8),
                        _buildQuickChip(
                            'Full', () => selectAmount(1.0), setSheetState),
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
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          prefixText: 'Rs  ',
                          prefixStyle: const TextStyle(
                            fontSize: 18,
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
                            borderSide:
                                const BorderSide(color: _primary, width: 2),
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
                          if (val > _supplier.balance)
                            return 'Cannot exceed due amount';
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
                                  colors: [_primary, _primaryDark],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color: isSaving ? Colors.grey.shade300 : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isSaving
                              ? []
                              : [
                                  BoxShadow(
                                    color: _primary.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate())
                                    return;
                                  setSheetState(() => isSaving = true);

                                  final amount =
                                      double.parse(amountController.text);
                                  final paymentEntry = SupplierPurchaseEntity(
                                    id: DateTime.now()
                                        .microsecondsSinceEpoch
                                        .toString(),
                                    supplierId: _supplier.id,
                                    supplierName: _supplier.name,
                                    date: DateTime.now(),
                                    items: const [],
                                    totalAmount: 0,
                                    amountPaid: amount,
                                  );

                                  await di.sl<AddSupplierPurchaseUseCase>()(
                                      paymentEntry);

                                  if (!mounted) return;

                                  parentContext
                                      .read<SupplierPurchaseBloc>()
                                      .add(LoadSupplierPurchasesEvent(
                                          _supplier.id));

                                  final refreshed = await di
                                      .sl<GetSupplierByIdUseCase>()(
                                      _supplier.id);
                                  if (refreshed != null && mounted) {
                                    setState(() => _supplier = refreshed);
                                  }

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(parentContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                                Icons.check_circle_rounded,
                                                color: Colors.white,
                                                size: 18),
                                            const SizedBox(width: 8),
                                            const Text('Payment recorded!'),
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
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Confirm Payment',
                                      style: TextStyle(
                                        fontSize: 16,
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
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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

  Widget _buildQuickChip(
      String label, VoidCallback onTap, StateSetter setSheetState) {
    return GestureDetector(
      onTap: () {
        onTap();
        setSheetState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _primary.withValues(alpha: 0.15)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showPurchaseDetail(BuildContext context, SupplierPurchaseEntity p) {
    final isPayment = p.isPaymentTransaction;
    final headerColor =
        isPayment ? const Color(0xFF059669) : const Color(0xFF0369A1);
    final headerColorDark =
        isPayment ? const Color(0xFF047857) : const Color(0xFF075985);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),

            // ── Gradient header banner ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [headerColor, headerColorDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: headerColor.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPayment
                          ? Icons.south_west_rounded
                          : Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPayment ? 'Payment Details' : 'Purchase Details',
                          style:  TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.sp,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(p.date),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Body content ──
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (isPayment)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'This entry records a payment against outstanding supplier due.',
                              style: TextStyle(
                                color: Color(0xFF134E4A),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isPayment) ...[
                    // ── Items header ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                           Text(
                            'Items',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.sp,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${p.items.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Item cards ──
                    ...p.items.asMap().entries.map(
                      (entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: Colors.grey.shade100, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${idx + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Color(0xFF0369A1),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style:  TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.sp,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.quantity} ${item.unit} × ${_money.format(item.price)}',
                                      style:  TextStyle(
                                        fontSize: 10.sp,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _money.format(item.total),
                                style:  TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.sp,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 8),

                  // ── Financial summary card ──
                  Container(
                    padding: const EdgeInsets.all(18),
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
                    child: Column(
                      children: [
                        _summaryRow(
                          'Total Amount',
                          _money.format(p.totalAmount),
                          const Color(0xFF334155),
                        ),
                        Divider(height: 18, color: Colors.grey.shade100),
                        _summaryRow(
                          'Amount Paid',
                          _money.format(p.amountPaid),
                          const Color(0xFF16A34A),
                        ),
                        Divider(height: 18, color: Colors.grey.shade100),
                        _summaryRow(
                          isPayment ? 'Remaining' : 'Due Balance',
                          _money.format(p.dueAmount),
                          p.dueAmount > 0
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF16A34A),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: isBold ? const Color(0xFF1E293B) : const Color(0xFF64748B),
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16.sp : 14.sp,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Future<void> _showEditSupplierSheet() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: _supplier.name);
    final phoneCtrl = TextEditingController(text: _supplier.phone);
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          StatefulBuilder(builder: (builderContext, setSheetState) {
        return Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Edit Supplier',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF0F172A),
                            ),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primary, _primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_note_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Update Supplier Profile',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Edit supplier details and keep purchase records clean.',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade100,
                            width: 1.5,
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
                          children: [
                            TextFormField(
                              controller: nameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Supplier Name',
                                hintText: 'e.g. ABC Wholesale',
                                prefixIcon: const Icon(
                                  Icons.business_rounded,
                                  color: _primary,
                                  size: 20,
                                ),
                                labelStyle: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: _primary, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Supplier name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: 'e.g. 9876543210',
                                prefixIcon: const Icon(
                                  Icons.phone_rounded,
                                  color: _primary,
                                  size: 20,
                                ),
                                labelStyle: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: _primary, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Phone number is required';
                                }
                                if (value.trim().length != 10) {
                                  return 'Phone number must be exactly 10 digits';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tip: Keep the phone number accurate for fast supplier lookup.',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }

                                  setSheetState(() => isSaving = true);

                                  final updated = _supplier.copyWith(
                                    name: nameCtrl.text.trim(),
                                    phone: phoneCtrl.text.trim(),
                                  );

                                  try {
                                    await di
                                        .sl<UpdateSupplierUseCase>()(updated);

                                    if (!mounted) {
                                      return;
                                    }

                                    final refreshed =
                                        await di.sl<GetSupplierByIdUseCase>()(
                                      _supplier.id,
                                    );
                                    if (refreshed != null && mounted) {
                                      setState(() => _supplier = refreshed);
                                    }

                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Supplier updated successfully',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setSheetState(() => isSaving = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor:
                                              const Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
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
                              : const Text(
                                  'Update Supplier',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  void _confirmDeleteSupplier() {
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
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Delete Supplier',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to remove "${_supplier.name}"? This action cannot be undone.',
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
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await di.sl<DeleteSupplierUseCase>()(_supplier.id);
                      if (!mounted) {
                        return;
                      }
                      Navigator.pop(ctx);
                      context.pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Supplier deleted'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

  double _previousDueBefore(
    SupplierPurchaseEntity selected,
    List<SupplierPurchaseEntity> all,
  ) {
    final asc = [...all]..sort((a, b) => a.date.compareTo(b.date));
    var runningDue = 0.0;

    for (final tx in asc) {
      if (tx.id == selected.id) {
        return runningDue < 0 ? 0.0 : runningDue;
      }
      runningDue += (tx.totalAmount - tx.amountPaid);
      if (runningDue < 0) {
        runningDue = 0.0;
      }
    }
    return 0.0;
  }

  Future<void> _printSupplierTransaction(
    BuildContext context,
    SupplierPurchaseEntity tx,
    double previousDue,
  ) async {
    final printerHelper = PrinterHelper();

    final shop = HiveDatabase.shopBox.values.isNotEmpty
        ? HiveDatabase.shopBox.values.first
        : null;

    final ShopModel? shopModel = shop;
    final shopName = shopModel?.name ?? 'Shop';
    final address1 = shopModel?.addressLine1 ?? '';
    final address2 = shopModel?.addressLine2 ?? '';
    final phone = shopModel?.phoneNumber ?? '';
    final footer = shopModel?.footerText ?? 'Thank you!';

    final items = tx.items
        .map((item) => {
              'name': item.productName,
              'qty': item.quantity,
              'price': item.price,
              'total': item.total,
            })
        .toList();

    final total = tx.totalAmount;

    try {
      await printerHelper.printReceipt(
        shopName: shopName,
        address1: address1,
        address2: address2,
        phone: phone,
        items: items,
        total: total,
        prevDue: previousDue,
        amountPaid: tx.amountPaid,
        footer: footer,
        customerName:
            tx.supplierName.isNotEmpty ? tx.supplierName : _supplier.name,
        partyLabel: 'Supplier',
        paymentMethod: 'cash',
        upiId: shopModel?.upiId ?? '',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction printed successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final hasDue = _supplier.balance > 0;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 4,
        leading: AppBackButton(onPressed: () => context.pop(), leftPadding: 0),
        title: Text(
          _supplier.name,
          style:  TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20.sp,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF0F172A)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            elevation: 4,
            offset: const Offset(0, 40),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'edit') {
                _showEditSupplierSheet();
              } else if (value == 'delete') {
                _confirmDeleteSupplier();
              }
            },
            itemBuilder: (context) => [
               PopupMenuItem(
                value: 'edit',
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.edit_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      'Edit',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 6),
              const PopupMenuItem(
                value: 'delete',
                height: 34,
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_sweep_rounded,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.24),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
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
                                style:  TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 3),
                            Text(
                              _supplier.phone.isEmpty
                                  ? 'No phone'
                                  : _supplier.phone,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _money.format(_supplier.balance),
                                style:  TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasDue)
                          FilledButton.icon(
                            onPressed: _showPaymentSheet,
                            icon:  Icon(Icons.payments_rounded, size: 16.sp),
                            label:  Text(
                              'Pay Due',
                              style: TextStyle(fontWeight: FontWeight.w700,fontSize: 12.sp),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.22),
                              foregroundColor: Colors.white,
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
          Padding(
            padding:  EdgeInsets.symmetric(horizontal: 10.h),
            child: SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await context.push('/suppliers/${_supplier.id}/purchase',
                      extra: _supplier);
                  if (!mounted) return;

                  context
                      .read<SupplierPurchaseBloc>()
                      .add(LoadSupplierPurchasesEvent(_supplier.id));

                  final updated =
                      await di.sl<GetSupplierByIdUseCase>()(_supplier.id);
                  if (mounted && updated != null) {
                    setState(() => _supplier = updated);
                  }
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label:  Text(
                  'Record Purchase',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
           SizedBox(height: 16.sp),

          // ── Activity Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                 Text(
                  'Purchase History',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                BlocBuilder<SupplierPurchaseBloc, SupplierPurchaseState>(
                  builder: (context, state) {
                    if (state.purchases.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${state.purchases.length} entries',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Activity list ──
          Expanded(
            child: BlocBuilder<SupplierPurchaseBloc, SupplierPurchaseState>(
              builder: (context, state) {
                if (state.status == SupplierPurchaseStatus.loading) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF0F766E)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loading activity…',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (state.purchases.isEmpty) {
                  return Center(
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
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.receipt_long_rounded,
                              size: 48, color: Color(0xFFCBD5E1)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No activity yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Record a purchase to get started',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: state.purchases.length,
                  itemBuilder: (context, i) {
                    final p = state.purchases[i];
                    final isPayment = p.isPaymentTransaction;
                    final previousDue = _previousDueBefore(p, state.purchases);
                    final date = p.date;

                    // Color coding based on status
                    final Color borderColor;
                    final String statusLabel;
                    if (isPayment) {
                      borderColor = const Color(0xFF10B981);
                      statusLabel = 'Payment';
                    } else if (p.dueAmount > 0 && p.amountPaid > 0) {
                      borderColor = const Color(0xFFF59E0B);
                      statusLabel = 'Partial';
                    } else if (p.dueAmount > 0) {
                      borderColor = Colors.red.shade400;
                      statusLabel = 'Unpaid';
                    } else {
                      borderColor = const Color(0xFF10B981);
                      statusLabel = 'Settled';
                    }

                    return GestureDetector(
                      onTap: () => _showPurchaseDetail(context, p),
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
                                  borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(18)),
                                  border: Border(
                                    left: BorderSide(
                                        color: borderColor, width: 4),
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat('dd').format(date),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: borderColor,
                                        height: 1,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM').format(date).toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: borderColor,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('yy').format(date),
                                      style: TextStyle(
                                        fontSize: 10,
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Time + status pill
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded,
                                              size: 12,
                                              color: Colors.grey.shade400),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('hh:mm a').format(date),
                                            style: TextStyle(
                                              fontSize: 10.sp,
                                              color: Colors.grey.shade500,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: borderColor.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: borderColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Amount row
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              isPayment
                                                  ? _money.format(p.amountPaid)
                                                  : _money.format(p.totalAmount),
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: isPayment
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (!isPayment) ...[
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Paid ${_money.format(p.amountPaid)}',
                                                  style:  TextStyle(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (p.dueAmount > 0)
                                                  Text(
                                                    'Due ${_money.format(p.dueAmount)}',
                                                    style: TextStyle(
                                                      fontSize: 10.sp,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          p.amountPaid > 0
                                                              ? const Color(
                                                                  0xFFF59E0B)
                                                              : Colors.red
                                                                  .shade600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),

                                      // Bottom row: item count + print
                                      Row(
                                        children: [
                                          if (isPayment)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFECFDF5),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .south_west_rounded,
                                                      size: 11,
                                                      color:
                                                          Color(0xFF059669)),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'DUE PAYMENT',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          Color(0xFF059669),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                    0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${p.items.length} item${p.items.length == 1 ? '' : 's'}',
                                                style:  TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          const Spacer(),
                                          InkWell(
                                            onTap: () =>
                                                _printSupplierTransaction(
                                              context,
                                              p,
                                              previousDue,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                    0xFFF0FDFA),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child:  Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.print_rounded,
                                                    size: 14,
                                                    color:
                                                        Color(0xFF0F766E),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Print',
                                                    style: TextStyle(
                                                      fontSize: 10.sp,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          Color(0xFF0F766E),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 16,
                                              color: Color(0xFFCBD5E1)),
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
