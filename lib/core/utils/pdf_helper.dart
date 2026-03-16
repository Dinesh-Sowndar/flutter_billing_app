import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:billing_app/features/billing/domain/entities/order_entity.dart';

class PdfHelper {
  static Future<void> generateAndPrintPdf({
    required OrderEntity order,
    required String address1,
    required String address2,
    required String phone,
    required String footer,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Thermal printer width approximately
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Shop Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(order.shopName,
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    if (address1.isNotEmpty) pw.Text(address1),
                    if (address2.isNotEmpty) pw.Text(address2),
                    pw.Text(phone),
                    pw.SizedBox(height: 5),
                    pw.Text(DateFormat('dd-MM-yyyy hh:mm a')
                        .format(order.dateTime)),
                    pw.SizedBox(height: 5),
                    pw.Text('--------------------------------'),
                  ],
                ),
              ),

              // Items Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                      flex: 3,
                      child: pw.Text('Item',
                          style:
                              pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(
                      child: pw.Text('Qty',
                          textAlign: pw.TextAlign.right,
                          style:
                              pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(
                      child: pw.Text('Price',
                          textAlign: pw.TextAlign.right,
                          style:
                              pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(
                      child: pw.Text('Total',
                          textAlign: pw.TextAlign.right,
                          style:
                              pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Text('--------------------------------'),

              // Items
              ...order.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(item.product.name)),
                      pw.Expanded(
                          child: pw.Text(item.quantity.toString(),
                              textAlign: pw.TextAlign.right)),
                      pw.Expanded(
                          child: pw.Text(item.product.price.toStringAsFixed(2),
                              textAlign: pw.TextAlign.right)),
                      pw.Expanded(
                          child: pw.Text(item.total.toStringAsFixed(2),
                              textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }),

              pw.Text('--------------------------------'),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.SizedBox(),
                  pw.Row(
                    children: [
                      pw.Text('TOTAL: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('INR ${order.totalAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Footer
              pw.Center(
                child: pw.Text(footer, textAlign: pw.TextAlign.center),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
