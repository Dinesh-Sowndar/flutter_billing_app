import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/supplier_entity.dart';
import '../../domain/entities/supplier_purchase_entity.dart';
import '../../domain/usecases/supplier_purchase_usecases.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../../core/service_locator.dart' as di;

const _kUnits = ['KG', 'Litre', 'Box', 'Piece'];

// ---------------------------------------------------------------------------
// Internal purchase-item model
// ---------------------------------------------------------------------------
class _PurchaseItem {
  String productId;
  String productName;
  double quantity;
  String unit;
  double price;

  _PurchaseItem({
    this.productId = '',
    this.productName = '',
    this.quantity = 1,
    this.unit = 'Piece',
    this.price = 0,
  });

  double get total => quantity * price;
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------
class SupplierPurchasePage extends StatefulWidget {
  final SupplierEntity supplier;
  const SupplierPurchasePage({super.key, required this.supplier});

  @override
  State<SupplierPurchasePage> createState() => _SupplierPurchasePageState();
}

class _SupplierPurchasePageState extends State<SupplierPurchasePage> {
  static const Color _primary = Color(0xFF0F766E);
  static const Color _primaryDark = Color(0xFF115E59);
  static const Color _surface = Color(0xFFF1F5F9);

  final List<_PurchaseItem> _items = [_PurchaseItem()];
  final _amountPaidCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountPaidCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, i) => sum + i.total);
  double get _previousDue => widget.supplier.balance;
  double get _grandTotal => _subtotal + _previousDue;

  void _addItem() => setState(() => _items.add(_PurchaseItem()));

  void _removeItem(int idx) {
    if (_items.length == 1) return;
    setState(() => _items.removeAt(idx));
  }

  Future<void> _submit() async {
    for (final item in _items) {
      if (item.productId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an item from inventory for every row'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    setState(() => _isSubmitting = true);

    final amountPaid = double.tryParse(_amountPaidCtrl.text) ?? 0;
    if (amountPaid > _grandTotal) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount paid cannot exceed grand total (Rs ${_grandTotal.toStringAsFixed(2)})',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final purchase = SupplierPurchaseEntity(
      id: const Uuid().v4(),
      supplierId: widget.supplier.id,
      supplierName: widget.supplier.name,
      date: DateTime.now(),
      totalAmount: _subtotal,
      amountPaid: amountPaid,
      items: _items
          .map((i) => SupplierPurchaseItemEntity(
                productId: i.productId,
                productName: i.productName,
                quantity: i.quantity,
                unit: i.unit,
                price: i.price,
                total: i.total,
              ))
          .toList(),
    );

    // Await the use case directly — ensures Hive is written (balance + stock)
    // BEFORE we pop, so supplier_detail_page reads the updated balance.
    await di.sl<AddSupplierPurchaseUseCase>()(purchase);

    if (mounted) {
      // Also reload global ProductBloc so inventory stock is live
      context.read<ProductBloc>().add(LoadProducts());
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Record Purchase',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, productState) {
          final allProducts = productState.products;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.supplier.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Add inventory purchase items and split paid/due amount.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Items',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(_items.length, (idx) {
                // Exclude products already chosen in other rows
                final usedIds = _items
                    .asMap()
                    .entries
                    .where((e) => e.key != idx && e.value.productId.isNotEmpty)
                    .map((e) => e.value.productId)
                    .toSet();
                final available =
                    allProducts.where((p) => !usedIds.contains(p.id)).toList();

                return _ItemRow(
                  key: ValueKey(idx),
                  index: idx,
                  item: _items[idx],
                  availableProducts: available,
                  onChanged: () => setState(() {}),
                  onRemove: () => _removeItem(idx),
                  canRemove: _items.length > 1,
                );
              }),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: _primary),
                label: const Text(
                  'Add Another Item',
                  style:
                      TextStyle(color: _primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              _SummaryCard(
                subtotal: _subtotal,
                previousDue: _previousDue,
                amountPaidCtrl: _amountPaidCtrl,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Save Purchase Entry',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single item row — inventory-only selection via searchable dropdown
// ---------------------------------------------------------------------------
class _ItemRow extends StatefulWidget {
  final int index;
  final _PurchaseItem item;
  final List availableProducts; // List<Product>
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final bool canRemove;

  const _ItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.availableProducts,
    required this.onChanged,
    required this.onRemove,
    required this.canRemove,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _showDropdown = false;
  List _suggestions = [];

  @override
  void initState() {
    super.initState();
    _qtyCtrl.text =
        widget.item.quantity == 1 ? '' : widget.item.quantity.toString();
    _priceCtrl.text =
        widget.item.price == 0 ? '' : widget.item.price.toString();
    if (widget.item.productName.isNotEmpty) {
      _searchCtrl.text = widget.item.productName;
    }
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        // Delay so tap on list item registers before closing
        Future.delayed(const Duration(milliseconds: 150),
            () => mounted ? setState(() => _showDropdown = false) : null);
      }
    });
  }

  @override
  void didUpdateWidget(_ItemRow old) {
    super.didUpdateWidget(old);
    // Re-filter suggestions whenever available list changes
    if (old.availableProducts != widget.availableProducts && _showDropdown) {
      _filterSuggestions(_searchCtrl.text);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _filterSuggestions(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _suggestions = q.isEmpty
          ? widget.availableProducts
          : widget.availableProducts
              .where((p) => p.name.toLowerCase().contains(q))
              .toList();
    });
  }

  void _selectProduct(dynamic product) {
    _searchCtrl.text = product.name;
    widget.item.productId = product.id;
    widget.item.productName = product.name;
    setState(() => _showDropdown = false);
    _searchFocus.unfocus();
    widget.onChanged();
  }

  bool get _hasSelection => widget.item.productId.isNotEmpty;

  InputDecoration _fieldDecor(String label, {String? prefixText}) =>
      InputDecoration(
        labelText: label,
        prefixText: prefixText,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            children: [
              Text('Item ${widget.index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF64748B))),
              const Spacer(),
              if (widget.canRemove)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: const Icon(Icons.remove_circle_outline_rounded,
                      color: Color(0xFFEF4444), size: 20),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Item selector ───────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search field
              TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                readOnly: _hasSelection, // lock after selection
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B)),
                decoration: _fieldDecor('Select Item').copyWith(
                  hintText: 'Search inventory...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF0F766E), size: 20),
                  suffixIcon: _hasSelection
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF94A3B8), size: 20),
                          onPressed: () {
                            _searchCtrl.clear();
                            widget.item.productId = '';
                            widget.item.productName = '';
                            setState(() => _showDropdown = false);
                            widget.onChanged();
                          },
                        )
                      : GestureDetector(
                          onTap: () {
                            _filterSuggestions(_searchCtrl.text);
                            setState(() => _showDropdown = true);
                            _searchFocus.requestFocus();
                          },
                          child: const Icon(Icons.arrow_drop_down,
                              color: Color(0xFF0F766E)),
                        ),
                ),
                onChanged: (v) {
                  _filterSuggestions(v);
                  setState(() => _showDropdown = true);
                },
                onTap: () {
                  if (!_hasSelection) {
                    _filterSuggestions(_searchCtrl.text);
                    setState(() => _showDropdown = true);
                  }
                },
              ),

              // Dropdown list
              if (_showDropdown)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _suggestions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No matching items in inventory',
                            style: TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Colors.grey.shade100),
                          itemBuilder: (_, i) {
                            final p = _suggestions[i];
                            return ListTile(
                              dense: true,
                              title: Text(p.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              onTap: () => _selectProduct(p),
                            );
                          },
                        ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Quantity + Unit ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,3}')),
                  ],
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B)),
                  decoration: _fieldDecor('Quantity').copyWith(hintText: '1'),
                  onChanged: (v) {
                    widget.item.quantity = double.tryParse(v) ?? 1;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: widget.item.unit,
                  items: _kUnits
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => widget.item.unit = v);
                      widget.onChanged();
                    }
                  },
                  decoration: _fieldDecor('Unit'),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Price + Row total ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B)),
                  decoration:
                      _fieldDecor('Purchase Price / Unit', prefixText: '₹ ')
                          .copyWith(hintText: '0.00'),
                  onChanged: (v) {
                    widget.item.price = double.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Row Total',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0F766E),
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '₹${widget.item.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F766E)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------
class _SummaryCard extends StatelessWidget {
  final double subtotal;
  final double previousDue;
  final TextEditingController amountPaidCtrl;
  final VoidCallback onChanged;

  const _SummaryCard({
    required this.subtotal,
    required this.previousDue,
    required this.amountPaidCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final paid = double.tryParse(amountPaidCtrl.text) ?? 0;
    final grandTotal = subtotal + previousDue;
    final due = (grandTotal - paid).clamp(0.0, grandTotal);
    final overpay = paid > grandTotal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Previous Due',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF64748B))),
              Text('₹${previousDue.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: previousDue > 0
                          ? const Color(0xFFD97706)
                          : const Color(0xFF16A34A))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF64748B))),
              Text('₹${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF334155))),
              Text('₹${grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFF0F766E))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountPaidCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: 'Amount Paid',
              hintText: 'Enter payment against grand total',
              prefixText: '₹ ',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF0F766E), width: 2),
              ),
              errorText: overpay ? 'Amount cannot exceed grand total' : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Balance Due',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF64748B))),
              Text('₹${due.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: due > 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF16A34A))),
            ],
          ),
        ],
      ),
    );
  }
}
