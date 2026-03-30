import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
    final ctrl =
        TextEditingController(text: _supplier.balance.toStringAsFixed(2));
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          StatefulBuilder(builder: (builderContext, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pay Supplier Due',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current due: ${_money.format(_supplier.balance)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Amount paid',
                      prefixText: 'Rs ',
                      helperText:
                          'This will be recorded as a payment transaction.',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter payment amount';
                      }
                      final amount = double.tryParse(value.trim());
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }
                      if (amount > _supplier.balance) {
                        return 'Amount cannot exceed current due';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }

                              final amount = double.parse(ctrl.text.trim());
                              setSheetState(() => isSaving = true);

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

                              if (!mounted) {
                                return;
                              }

                              parentContext.read<SupplierPurchaseBloc>().add(
                                  LoadSupplierPurchasesEvent(_supplier.id));

                              final refreshed = await di
                                  .sl<GetSupplierByIdUseCase>()(_supplier.id);
                              if (refreshed != null && mounted) {
                                setState(() => _supplier = refreshed);
                              }

                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                                ScaffoldMessenger.of(parentContext)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${_money.format(amount)} payment recorded as transaction',
                                    ),
                                    backgroundColor: const Color(0xFF059669),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.payments_rounded),
                      label: Text(isSaving ? 'Saving...' : 'Save Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  void _showPurchaseDetail(BuildContext context, SupplierPurchaseEntity p) {
    final isPayment = p.isPaymentTransaction;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  Text(
                    isPayment ? 'Payment Details' : 'Purchase Details',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd MMM yyyy').format(p.date),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (isPayment)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF99F6E4)),
                      ),
                      child: const Text(
                        'This entry records a payment against outstanding supplier due.',
                        style: TextStyle(
                          color: Color(0xFF134E4A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (!isPayment)
                    ...p.items.map(
                      (item) => Container(
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
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item.quantity} ${item.unit} x ${_money.format(item.price)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _money.format(item.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(height: 24),
                  _detailRow('Total', _money.format(p.totalAmount), bold: true),
                  const SizedBox(height: 6),
                  _detailRow('Paid', _money.format(p.amountPaid),
                      valueColor: const Color(0xFF16A34A)),
                  const SizedBox(height: 6),
                  _detailRow('Due', _money.format(p.dueAmount),
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
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: const Color(0xFF0F172A),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _supplier.name,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Color(0xFF0F172A),
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
              const PopupMenuItem(
                value: 'edit',
                height: 34,
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Text(
                      'Edit',
                      style: TextStyle(fontSize: 14),
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
                                style: const TextStyle(
                                  fontSize: 21,
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
                            icon: const Icon(Icons.payments_rounded, size: 18),
                            label: const Text(
                              'Pay Due',
                              style: TextStyle(fontWeight: FontWeight.w700),
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
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
                label: const Text(
                  'Record Purchase',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ACTIVITY',
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
                          'No activity yet',
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
                    final isPayment = p.isPaymentTransaction;
                    final previousDue = _previousDueBefore(p, state.purchases);

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
                                color: isPayment
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isPayment
                                    ? Icons.south_west_rounded
                                    : Icons.receipt_rounded,
                                color: isPayment
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF0369A1),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPayment
                                        ? 'Due Payment'
                                        : '${p.items.length} item${p.items.length != 1 ? 's' : ''}',
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
                                  isPayment
                                      ? _money.format(p.amountPaid)
                                      : _money.format(p.totalAmount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: isPayment
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                if (isPayment)
                                  const Text(
                                    'Payment',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF059669),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                else if (p.dueAmount > 0)
                                  Text(
                                    'Due ${_money.format(p.dueAmount)}',
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
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => _printSupplierTransaction(
                                    context,
                                    p,
                                    previousDue,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.print_rounded,
                                          size: 14,
                                          color: Color(0xFF0F766E),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Print',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ],
                                    ),
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
