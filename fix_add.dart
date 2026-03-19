import 'dart:io';

void main() {
  final file = File('lib/features/product/presentation/pages/add_product_page.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('package:flutter/services.dart')) {
    content = content.replaceFirst(
        "import 'package:flutter/material.dart';", 
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';");
  }

  content = content.replaceFirst(
    '''
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
                  ),''',
    '''
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Product Name'),
                  TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'e.g. Basmati Rice 1kg',
                      prefixIcon: Icon(Icons.inventory_2_outlined,
                          color: Color(0xFF94A3B8)),
                      counterText: '',
                    ),
                    maxLength: 30,
                    textCapitalization: TextCapitalization.words,
                    validator: AppValidators.required('Please enter a name'),
                    onSaved: (value) => _name = value!,
                  ),'''
  );

  final priceRegex = RegExp(r"const SizedBox\(height: 24\),\s*const InputLabel\(text: 'Selling Price'\),\s*TextFormField\([^;]+=> _price = double\.parse\(value!\),\s*\),");
  final match = priceRegex.firstMatch(content);
  if (match != null) {
      content = content.replaceFirst(priceRegex, '''
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
                      counterText: '',
                    ),
                    maxLength: 8,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\\\\d{0,8}(\\\\.\\\\d{0,2})?')),
                    ],
                    validator: AppValidators.price,
                    onSaved: (value) => _price = double.parse(value!),
                  ),''');
  } else {
    print('Price match not found');
  }

  file.writeAsStringSync(content);
}
