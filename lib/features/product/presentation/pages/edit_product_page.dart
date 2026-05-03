import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import 'package:billing_app/core/service_locator.dart';
import 'package:billing_app/core/services/image_service.dart';
import 'dart:io';

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
  late String _category;
  late double _taxPercent;
  late String _description;
  String? _imageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _name = widget.product.name;
    _price = widget.product.price;
    _category = widget.product.category ?? 'Uncategorized';
    _taxPercent = widget.product.taxPercent ?? 0.0;
    _description = widget.product.description ?? '';
    _imageUrl = widget.product.imageUrl;
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final updatedProduct = Product(
        id: widget.product.id,
        name: _name,
        barcode: widget.product.barcode,
        price: _price,
        category: _category,
        taxPercent: _taxPercent,
        description: _description,
        imageUrl: _imageUrl,
      );

      context.read<ProductBloc>().add(UpdateProduct(updatedProduct));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 32, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Edit Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display Barcode details (immutable block)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_scanner,
                            color: AppTheme.primaryColor, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BARCODE',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.7))),
                            const SizedBox(height: 2),
                            Text(widget.product.barcode,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace')),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const InputLabel(text: 'Product Name'),

                  TextFormField(
                    initialValue: _name,
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a name'),
                    onSaved: (value) => _name = value!,
                  ),
                  const SizedBox(height: 24),

                  const InputLabel(text: 'Price'),

                  TextFormField(
                    initialValue: _price.toStringAsFixed(2),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    validator: AppValidators.price,
                    onSaved: (value) => _price = double.parse(value!),
                  ),

                  const SizedBox(height: 20),
                  const InputLabel(text: 'Categorie'),
                  TextFormField(
                    initialValue: _category,
                    decoration: const InputDecoration(hintText: 'e.g. Rice'),
                    onSaved: (value) => _category = value ?? _category,
                  ),

                  const SizedBox(height: 20),
                  const InputLabel(text: 'Taxe (%)'),
                  TextFormField(
                    initialValue: _taxPercent.toString(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'e.g. 5.0'),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final v = double.tryParse(value);
                      if (v == null) return 'Entrez un nombre valide';
                      return null;
                    },
                    onSaved: (value) => _taxPercent =
                        (value == null || value.isEmpty)
                            ? 0.0
                            : double.parse(value),
                  ),

                  const SizedBox(height: 20),
                  const InputLabel(text: 'Description'),
                  TextFormField(
                    initialValue: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Optional'),
                    onSaved: (value) => _description = value ?? '',
                  ),

                  const SizedBox(height: 20),
                  const InputLabel(text: 'Image du produit'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _imageUrl != null
                          ? Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade300)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(_imageUrl!),
                                    fit: BoxFit.cover),
                              ),
                            )
                          : Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade300)),
                              child:
                                  const Icon(Icons.image, color: Colors.grey),
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isUploadingImage
                                  ? null
                                  : () async {
                                      try {
                                        setState(
                                            () => _isUploadingImage = true);
                                        final path = await sl<ImageService>()
                                            .pickImageFromCamera();
                                        if (path != null) {
                                          setState(() => _imageUrl = path);
                                        }
                                      } finally {
                                        setState(
                                            () => _isUploadingImage = false);
                                      }
                                    },
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isUploadingImage
                                  ? null
                                  : () async {
                                      try {
                                        setState(
                                            () => _isUploadingImage = true);
                                        final path = await sl<ImageService>()
                                            .pickImageFromGallery();
                                        if (path != null) {
                                          setState(() => _imageUrl = path);
                                        }
                                      } finally {
                                        setState(
                                            () => _isUploadingImage = false);
                                      }
                                    },
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isUploadingImage) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _submit,
          icon: Icons.save,
          label: 'Enregistrer les modifications',
        ));
  }
}
