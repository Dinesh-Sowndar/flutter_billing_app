import 'package:flutter/material.dart';
import '../../domain/erp_models.dart';

class InvoicePrintPage extends StatefulWidget {
  const InvoicePrintPage({super.key});
  @override
  State<InvoicePrintPage> createState() => _InvoicePrintPageState();
}

class _InvoicePrintPageState extends State<InvoicePrintPage> {
  PrintMode _mode = PrintMode.withPad;
  double _marginMm = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice print preview')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: SegmentedButton<PrintMode>(segments: const [ButtonSegment(value: PrintMode.withPad, label: Text('WITH_PAD')), ButtonSegment(value: PrintMode.withoutPad, label: Text('WITHOUT_PAD'))], selected: {_mode}, onSelectionChanged: (value) => setState(() => _mode = value.first))),
        Row(children: [const SizedBox(width: 16), const Text('Margins (mm)'), Expanded(child: Slider(min: 0, max: 30, divisions: 30, value: _marginMm, label: _marginMm.toStringAsFixed(0), onChanged: (value) => setState(() => _marginMm = value)))]),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 210 / 297, child: Container(color: Colors.grey.shade300, padding: EdgeInsets.all(_marginMm * 2.8), child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, border: _mode == PrintMode.withPad ? Border.all(color: Colors.black12) : null), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('AL-NOOR DIGITAL PRINT HOUSE', style: TextStyle(fontWeight: FontWeight.bold)), const Text('INVOICE  INV-2026-0001'), const Divider(), const Text('Print job / customer details'), const Spacer(), const Align(alignment: Alignment.centerRight, child: Text('TOTAL  ৳1,440.00', style: TextStyle(fontWeight: FontWeight.bold)))])))))),
      ]),
    );
  }
}
