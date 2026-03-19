$AddProdPath = "lib/features/product/presentation/pages/add_product_page.dart"
$EditProdPath = "lib/features/product/presentation/pages/edit_product_page.dart"

$AddProd = Get-Content $AddProdPath -Raw
$EditProd = Get-Content $EditProdPath -Raw

if ($AddProd -notmatch 'package:flutter/services.dart') {
    $AddProd = $AddProd -replace "(import 'package:flutter/material.dart';)" , "$1
import 'package:flutter/services.dart';"
}
if ($EditProd -notmatch 'package:flutter/services.dart') {
    $EditProd = $EditProd -replace "(import 'package:flutter/material.dart';)" , "$1
import 'package:flutter/services.dart';"
}

$AddProdNameOld = 'textCapitalization: TextCapitalization.words,
                  validator: AppValidators.required\(''Please enter a name''\),
                  onSaved: \(value\) => _name = value!,'

$AddProdNameNew = 'maxLength: 30,
                  buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.required(''Please enter a name''),
                  onSaved: (value) => _name = value!,'

$AddProdPriceOld = 'validator: AppValidators.price,
                  onSaved: \(value\) => _price = double.parse\(value!\),'

$AddProdPriceNew = 'maxLength: 8,
                  buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r''^\d{0,8}(\.\d{0,2})?'')),
                  ],
                  validator: AppValidators.price,
                  onSaved: (value) => _price = double.parse(value!),'

$EditProdNameOld = 'textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration\(
                    prefixIcon: Icon\(Icons.inventory_2_outlined,
                        color: Color\(0xFF94A3B8\)\),
                  \),
                  validator: AppValidators.required\(''Please enter a name''\),
                  onSaved: \(value\) => _name = value!,'

$EditProdNameNew = 'maxLength: 30,
                  buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.inventory_2_outlined,
                        color: Color(0xFF94A3B8)),
                  ),
                  validator: AppValidators.required(''Please enter a name''),
                  onSaved: (value) => _name = value!,'

$EditProdPriceOld = 'validator: AppValidators.price,
                  onSaved: \(value\) => _price = double.parse\(value!\),'

$EditProdPriceNew = 'maxLength: 8,
                  buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r''^\d{0,8}(\.\d{0,2})?'')),
                  ],
                  validator: AppValidators.price,
                  onSaved: (value) => _price = double.parse(value!),'

$AddProd = $AddProd -replace $AddProdNameOld, $AddProdNameNew
$AddProd = $AddProd -replace $AddProdPriceOld, $AddProdPriceNew

$EditProd = $EditProd -replace $EditProdNameOld, $EditProdNameNew
$EditProd = $EditProd -replace $EditProdPriceOld, $EditProdPriceNew

Set-Content $AddProdPath $AddProd -Encoding UTF8
Set-Content $EditProdPath $EditProd -Encoding UTF8

