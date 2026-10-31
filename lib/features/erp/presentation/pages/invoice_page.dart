import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});
  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final _widthController = TextEditingController(text: '4');
  final _heightController = TextEditingController(text: '3');
  final _rateController = TextEditingController(text: '120');
  final _quantityController = TextEditingController(text: '1');
  String _unit = 'SQFT';
  double _total = 1440;

  @override
  void dispose() {
    _widthController.dispose(); _heightController.dispose(); _rateController.dispose(); _quantityController.dispose(); super.dispose();
  }

  void _calculate() {
    final width = double.tryParse(_widthController.text) ?? 0;
    final height = double.tryParse(_heightController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    setState(() => _total = ((_unit == 'SQFT' ? width * height : 1) * rate * quantity).roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New print invoice')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        DropdownButtonFormField<String>(value: _unit, decoration: const InputDecoration(labelText: 'Pricing unit'), items: const [DropdownMenuItem(value: 'SQFT', child: Text('SQFT - square feet')), DropdownMenuItem(value: 'PCS', child: Text('PCS - pieces'))], onChanged: (value) => setState(() => _unit = value ?? 'SQFT')),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: TextField(controller: _widthController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Width'))), const SizedBox(width: 12), Expanded(child: TextField(controller: _heightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height')))]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: TextField(controller: _rateController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate (BDT)'))), const SizedBox(width: 12), Expanded(child: TextField(controller: _quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')))]),
        const SizedBox(height: 20),
        Card(child: ListTile(title: const Text('Line total'), trailing: Text('৳${_total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge))),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _calculate, icon: const Icon(Icons.calculate), label: const Text('Calculate BDT total')),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => context.push('/erp/print-preview'), icon: const Icon(Icons.print), label: const Text('Preview invoice print')),
      ]),
    );
  }
}
