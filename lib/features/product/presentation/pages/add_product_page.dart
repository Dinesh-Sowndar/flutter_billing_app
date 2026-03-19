import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _barcode = '';
  double _price = 0.0;
  int _stock = 0;
  QuantityUnit _unit = QuantityUnit.piece;

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcode = result;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final product = Product(
        id: const Uuid().v4(),
        name: _name,
        barcode: _barcode,
        price: _price,
        stock: _stock,
        unit: _unit,
      );

      context.read<ProductBloc>().add(AddProduct(product));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductBloc, ProductState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == ProductStatus.success ||
              current.status == ProductStatus.error),
      listener: (context, state) {
        if (state.status == ProductStatus.success) {
          context.pop();
        } else if (state.status == ProductStatus.error &&
            state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.chevron_left_rounded,
                size: 32, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Add Product',
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
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
                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color:
                              AppTheme.secondaryColor.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppTheme.secondaryColor),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Barcode is optional. You can add products without one and select them manually during checkout.',
                            style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const InputLabel(text: 'Barcode Number'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(_barcode),
                          initialValue: _barcode,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 890123456789 (optional)',
                            prefixIcon: Icon(Icons.qr_code_2_rounded,
                                color: Color(0xFF94A3B8)),
                          ),
                          // barcode is optional Ã¢â‚¬â€ no validator
                          onSaved: (value) => _barcode = value?.trim() ?? '',
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: _scanBarcode,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.document_scanner_rounded,
                              color: AppTheme.primaryColor),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const InputLabel(text: 'Product Name'),
                  TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'e.g. Basmati Rice 1kg',
                      prefixIcon: Icon(Icons.inventory_2_outlined,
                          color: Color(0xFF94A3B8)),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a name'),
                    onSaved: (value) => _name = value!,
                  ),

                  const SizedBox(height: 24),
                  const InputLabel(text: 'Selling Price'),
                  TextFormField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: 'â‚¹ ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B)),
                      counterText: '',
                    ),
                    maxLength: 8,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\\d{0,8}(\\.\\d{0,2})?')),
                    ],
                    validator: AppValidators.price,
                    onSaved: (value) => _price = double.parse(value!),
                  ),

                  const SizedBox(height: 24),
                  const InputLabel(text: 'Opening Stock'),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0',
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
                    onSaved: (value) => _stock =
                        (value != null && value.isNotEmpty)
                            ? int.parse(value)
                            : 0,
                  ),

                  const SizedBox(height: 24),
                  const InputLabel(text: 'Quantity Unit'),
                  const SizedBox(height: 8),
                  _UnitSelector(
                    selected: _unit,
                    onChanged: (unit) => setState(() => _unit = unit),
                  ),

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
            icon: Icons.add_rounded,
            label: 'Save Product',
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable unit chip selector
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                    color: isSelected ? Colors.white : const Color(0xFF334155),
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
