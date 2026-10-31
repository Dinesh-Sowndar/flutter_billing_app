import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/core/billing/billing_core.dart';

void main() {
  group('BDT', () {
    test('uses poisha and parses exactly', () {
      expect(Bdt.fromTaka('1.05').poisha, 105);
      expect(Bdt.fromTaka('0.1') + Bdt.fromTaka('0.05'), Bdt.fromTaka('0.15'));
      expect(Bdt.fromTaka('12').takaString, '12.00');
    });
  });

  test('calculates square-foot line with add-ons without doubles', () {
    final line = BillingLine.squareFoot(
      description: 'Vinyl',
      quantity: 2,
      widthInches: 24,
      heightInches: 36,
      pricePerSquareFoot: Bdt.fromTaka('100'),
      addOns: PricingAddOns(
        lamination: Lamination.gloss,
        laminationPerUnit: Bdt.fromTaka('10'),
        boardPasting: BoardPasting.single,
        boardPastingPerUnit: Bdt.fromTaka('5'),
        lightboxPerUnit: Bdt.fromTaka('2'),
      ),
    );
    // 2 * (24 * 36 / 144) = 12 sqft, at ৳117/sqft.
    expect(line.baseAmount, Bdt.fromTaka('1200'));
    expect(line.addOnAmount, Bdt.fromTaka('204'));
    expect(line.total, Bdt.fromTaka('1404'));
  });

  test('calculates piece line and all per-piece add-ons', () {
    final line = BillingLine.pieces(
      description: 'Foam board',
      quantity: 3,
      pricePerPiece: Bdt.fromTaka('25.50'),
      addOns: PricingAddOns(
        laminationPerUnit: Bdt.fromTaka('2'),
        boardPastingPerUnit: Bdt.fromTaka('3'),
        lightboxPerUnit: Bdt.fromTaka('1.50'),
      ),
    );
    expect(line.total, Bdt.fromTaka('96'));
  });

  test('settles split payments and reports change', () {
    final settlement = PaymentSettlement(
      due: Bdt.fromTaka('1000'),
      payments: [
        Payment(method: PaymentMethod.cash, amount: Bdt.fromTaka('400')),
        Payment(method: PaymentMethod.bKash, amount: Bdt.fromTaka('300')),
        Payment(method: PaymentMethod.nagad, amount: Bdt.fromTaka('200')),
        Payment(method: PaymentMethod.rocket, amount: Bdt.fromTaka('150')),
        Payment(method: PaymentMethod.bankTransfer, amount: Bdt.fromTaka('50')),
      ],
    );
    expect(settlement.paid, Bdt.fromTaka('1100'));
    expect(settlement.change, Bdt.fromTaka('100'));
    expect(settlement.outstanding, Bdt.zero);
    expect(settlement.isPaid, isTrue);
  });

  test('keeps document sequences independent by type and year', () {
    final numbers = DocumentNumberGenerator();
    expect(numbers.next(DocumentType.invoice, 2026), 'INV/2026/0001');
    expect(numbers.next(DocumentType.invoice, 2026), 'INV/2026/0002');
    expect(numbers.next(DocumentType.challan, 2026), 'CH/2026/0001');
    expect(numbers.next(DocumentType.invoice, 2027), 'INV/2027/0001');
    expect(numbers.next(DocumentType.quotation, 2026), 'QT/2026/0001');
  });
}
