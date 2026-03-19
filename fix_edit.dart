import 'dart:io';

void main() {
  final file = File('lib/features/product/presentation/pages/edit_product_page.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('package:flutter/services.dart')) {
    content = content.replaceFirst(
        "import 'package:flutter/material.dart';", 
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';");
  }

  // Find and replace Product Name
  final nameRegex = RegExp(r"const InputLabel\(text: 'Product Name'\),\s*TextFormField\([^;]+=> _name = value!,\s*\),");
  final matchName = nameRegex.firstMatch(content);
  if (matchName != null) {
      content = content.replaceFirst(nameRegex, '''
                const InputLabel(text: 'Product Name'),
                TextFormField(
                  initialValue: _name,
                  maxLength: 30,
                  buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.inventory_2_outlined,
                        color: Color(0xFF94A3B8)),
                    counterText: '',
                  ),
                  validator: AppValidators.required('Please enter a name'),
                  onSaved: (value) => _name = value!,
                ),''');
  }

  // Find and replace Selling Price
  final priceRegex = RegExp(r"const InputLabel\(text: 'Selling Price'\),\s*TextFormField\([^;]+=> _price = double\.parse\(value!\),\s*\),");
  final matchPrice = priceRegex.firstMatch(content);
  if (matchPrice != null) {
      content = content.replaceFirst(priceRegex, '''
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
                    counterText: '',
                  ),
                  maxLength: 8,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\\d{0,8}(\\.\\d{0,2})?')),
                  ],
                  validator: AppValidators.price,
                  onSaved: (value) => _price = double.parse(value!),
                ),''');
  }

  file.writeAsStringSync(content);
}
