import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
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

      final productState = context.read<ProductBloc>().state;
      final existingProduct =
          productState.products.where((p) => p.barcode == _barcode).firstOrNull;

      if (existingProduct != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product with barcode "$_barcode" already exists!'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      final product = Product(
        id: const Uuid().v4(),
        name: _name,
        barcode: _barcode,
        price: _price,
      );

      context.read<ProductBloc>().add(AddProduct(product));
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
        title: const Text('Add Product',
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
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppTheme.secondaryColor),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Scan the barcode on the product packaging to quickly fill in the details.',
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
                          hintText: 'e.g. 890123456789',
                          prefixIcon: Icon(Icons.qr_code_2_rounded,
                              color: Color(0xFF94A3B8)),
                        ),
                        validator:
                            AppValidators.required('Please enter a barcode'),
                        onSaved: (value) => _barcode = value!,
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
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B)),
                  ),
                  validator: AppValidators.price,
                  onSaved: (value) => _price = double.parse(value!),
                ),

                const SizedBox(height: 48), // Bottom padding
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
    );
  }
}
