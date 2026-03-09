import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _price;
  late int _stock;
  late QuantityUnit _unit;

  @override
  void initState() {
    super.initState();
    _name = widget.product.name;
    _price = widget.product.price;
    _stock = widget.product.stock;
    _unit = widget.product.unit;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final updatedProduct = widget.product.copyWith(
        name: _name,
        price: _price,
        stock: _stock,
        unit: _unit,
      );

      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded,
              size: 32, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Product',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display Barcode details (immutable block)
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFF1F5F9), width: 2),
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded,
                            color: AppTheme.primaryColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LINKED BARCODE',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 1.2)),
                            const SizedBox(height: 4),
                            Text(widget.product.barcode,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                      const Icon(Icons.lock_rounded,
                          color: Color(0xFFCBD5E1), size: 20),
                    ],
                  ),
                ),

                const InputLabel(text: 'Product Name'),
                TextFormField(
                  initialValue: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.inventory_2_outlined,
                        color: Color(0xFF94A3B8)),
                  ),
                  validator: AppValidators.required('Please enter a name'),
                  onSaved: (value) => _name = value!,
                ),

                const SizedBox(height: 24),
                const InputLabel(text: 'Selling Price'),
                TextFormField(
                  initialValue: _price.toStringAsFixed(2),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                  ),
                  validator: AppValidators.price,
                  onSaved: (value) => _price = double.parse(value!),
                ),

                const SizedBox(height: 24),
                const InputLabel(text: 'Stock'),
                TextFormField(
                  initialValue: _stock.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.warehouse_outlined,
                        color: Color(0xFF94A3B8)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    if (int.tryParse(value) == null) {
                      return 'Enter a valid integer';
                    }
                    return null;
                  },
                  onSaved: (value) =>
                      _stock = (value != null && value.isNotEmpty)
                          ? int.parse(value)
                          : _stock,
                ),

                const SizedBox(height: 24),
                const InputLabel(text: 'Quantity Unit'),
                const SizedBox(height: 8),
                StatefulBuilder(builder: (context, setChipState) {
                  return _UnitSelector(
                    selected: _unit,
                    onChanged: (unit) {
                      setChipState(() => _unit = unit);
                      setState(() => _unit = unit);
                    },
                  );
                }),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 12),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: PrimaryButton(
          onPressed: _submit,
          icon: Icons.save_rounded,
          label: 'Save Changes',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable unit chip selector (same as add_product_page)
// ---------------------------------------------------------------------------
class _UnitSelector extends StatelessWidget {
  final QuantityUnit selected;
  final ValueChanged<QuantityUnit> onChanged;

  const _UnitSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: QuantityUnit.values.map((unit) {
        final isSelected = unit == selected;
        return GestureDetector(
          onTap: () => onChanged(unit),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor
                    : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _unitIcon(unit),
                  size: 18,
                  color: isSelected ? Colors.white : AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  unit.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _unitIcon(QuantityUnit unit) {
    switch (unit) {
      case QuantityUnit.piece:
        return Icons.widgets_outlined;
      case QuantityUnit.kg:
        return Icons.scale_outlined;
      case QuantityUnit.liter:
        return Icons.water_drop_outlined;
      case QuantityUnit.box:
        return Icons.inventory_2_outlined;
    }
  }
}

