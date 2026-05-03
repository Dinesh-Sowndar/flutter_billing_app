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
import 'package:billing_app/core/service_locator.dart';
import 'package:billing_app/core/services/image_service.dart';
import 'dart:io';

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
  String _category = 'Non catégorisé';
  double _taxPercent = 0.0;
  String _description = '';
  String? _imageUrl;
  bool _isUploadingImage = false;

  Future<void> readImageFromCamera() async {
    try {
      setState(() => _isUploadingImage = true);
      final path = await sl<ImageService>().pickImageFromCamera();
      if (path != null) {
        setState(() => _imageUrl = path);
      }
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> pickImageFromGallery() async {
    try {
      setState(() => _isUploadingImage = true);
      final path = await sl<ImageService>().pickImageFromGallery();
      if (path != null) {
        setState(() => _imageUrl = path);
      }
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

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
            content: Text(
                'Produit  "$_barcode" existe déjà. Veuillez vérifier le code-barres.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final product = Product(
        id: const Uuid().v4(),
        name: _name,
        barcode: _barcode,
        price: _price,
        category: _category,
        taxPercent: _taxPercent,
        description: _description,
        imageUrl: _imageUrl,
      );

      context.read<ProductBloc>().add(AddProduct(product));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left,
                size: 28, color: Theme.of(context).primaryColor),
            onPressed: () => context.pop(),
          ),
          title: const Text('Add Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InputLabel(text: 'Barcode'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(_barcode),
                          initialValue: _barcode,
                          decoration: const InputDecoration(
                            hintText: 'Scan or enter barcode',
                          ),
                          validator:
                              AppValidators.required('Please enter a barcode'),
                          onSaved: (value) => _barcode = value!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner,
                              color: AppTheme.primaryColor),
                          onPressed: _scanBarcode,
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap the icon to open camera scanner',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4C669A))),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Nom du produit'),
                  TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'ex: Riz basmati',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required(
                        'Merci d\'entrer un nom de produit'),
                    onSaved: (value) => _name = value!,
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Prix'),
                  TextFormField(
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: '€ ',
                      prefixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    validator: AppValidators.price,
                    onSaved: (value) => _price = double.parse(value!),
                  ),
                  const SizedBox(height: 20),
                  const InputLabel(text: 'Catégorie'),
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
                                  : readImageFromCamera,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isUploadingImage
                                  ? null
                                  : pickImageFromGallery,
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
          icon: Icons.add_circle,
          label: 'Ajouter le produit',
        ));
  }
}
