import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/billing/data/models/transaction_model.dart';
import '../../features/shop/data/models/shop_model.dart';

class InvoicePdfShareHelper {
  static Future<void> shareTransactionPdf({
    required TransactionModel transaction,
    required ShopModel? shop,
    double? balanceDue,
  }) async {
    final pdf = pw.Document();
    pw.ThemeData pdfTheme;
    try {
      final baseFont = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();
      final italicFont = await PdfGoogleFonts.notoSansItalic();
      final boldItalicFont = await PdfGoogleFonts.notoSansBoldItalic();

      pdfTheme = pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        italic: italicFont,
        boldItalic: boldItalicFont,
      );
    } catch (_) {
      // Fallback keeps share working even if online font fetch fails.
      pdfTheme = pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      );
    }

    final isPaymentOnly =
        transaction.items.isEmpty && transaction.amountPaid > 0;
    final billNo = transaction.id.length > 8
        ? transaction.id.substring(0, 8).toUpperCase()
        : transaction.id.toUpperCase();

    final due = (transaction.totalAmount - transaction.amountPaid)
        .clamp(0.0, double.infinity)
        .toDouble();
    final shownBalance = balanceDue ?? due;

    final currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);
    final dateText = DateFormat('dd MMM yyyy, hh:mm a').format(transaction.date);

    pdf.addPage(
      pw.MultiPage(
        theme: pdfTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Text(
              shop?.name.isNotEmpty == true ? shop!.name : 'Shop',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 22,
              ),
            ),
            if (shop?.addressLine1.isNotEmpty == true)
              pw.Text(shop!.addressLine1),
            if (shop?.addressLine2.isNotEmpty == true)
              pw.Text(shop!.addressLine2),
            if (shop?.phoneNumber.isNotEmpty == true)
              pw.Text('Phone: ${shop!.phoneNumber}'),
            if (shop?.gstNumber.isNotEmpty == true)
              pw.Text('GSTIN: ${shop!.gstNumber}'),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              isPaymentOnly ? 'PAYMENT RECEIPT' : 'TAX INVOICE',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 15,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Bill No: $billNo'),
            pw.Text('Date: $dateText'),
            pw.Text(
              'Customer: ${transaction.customerName.isNotEmpty ? transaction.customerName : 'Guest Customer'}',
            ),
            pw.SizedBox(height: 14),
            if (!isPaymentOnly) ...[
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.2),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.4),
                  3: const pw.FlexColumnWidth(1.6),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Item', header: true),
                      _cell('Qty', header: true),
                      _cell('Rate', header: true),
                      _cell('Amount', header: true),
                    ],
                  ),
                  ...transaction.items.map(
                    (item) => pw.TableRow(
                      children: [
                        _cell(item.productName),
                        _cell(item.quantity.toString()),
                        _cell(currency.format(item.price), alignRight: true),
                        _cell(currency.format(item.total), alignRight: true),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
            ],
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  if (!isPaymentOnly) ...[
                    _summary('Bill Amount', currency.format(transaction.totalAmount)),
                    if (transaction.gstRate > 0) ...[
                      _summary(
                        'CGST (${(transaction.gstRate / 2).toStringAsFixed(1)}%)',
                        currency.format(transaction.cgstAmount),
                      ),
                      _summary(
                        'SGST (${(transaction.gstRate / 2).toStringAsFixed(1)}%)',
                        currency.format(transaction.sgstAmount),
                      ),
                    ],
                  ],
                  _summary('Amount Paid', currency.format(transaction.amountPaid)),
                  _summary(
                    isPaymentOnly ? 'Balance Due' : 'Due Amount',
                    currency.format(shownBalance),
                    emphasize: shownBalance > 0,
                  ),
                  _summary(
                    'Payment Method',
                    transaction.paymentMethod.toUpperCase(),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              shop?.footerText.isNotEmpty == true ? shop!.footerText : 'Thank you for your business!',
              style: pw.TextStyle(
                color: PdfColors.grey700,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/invoice_$billNo.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: isPaymentOnly ? 'Payment receipt $billNo' : 'Invoice $billNo',
      subject: isPaymentOnly ? 'Payment Receipt' : 'Invoice',
    );
  }

  static pw.Widget _cell(
    String text, {
    bool header = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Align(
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }

  static pw.Widget _summary(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: emphasize ? PdfColors.red700 : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
