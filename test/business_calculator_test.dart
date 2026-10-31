import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/operations/domain/business_models.dart';

void main() {
  group('BusinessCalculator', () {
    test('calculates piece billing with add-ons', () {
      final result = BusinessCalculator.calculateBill(
        lines: const [
          BillingLineInput(
            description: 'Cards',
            unit: BillingUnit.piece,
            unitRate: 4,
            pieces: 100,
            addOnTotal: 50,
          ),
        ],
        paid: 200,
      );

      expect(result.subtotal, 450);
      expect(result.netTotal, 450);
      expect(result.due, 250);
    });

    test('calculates area billing and percentage discount', () {
      final result = BusinessCalculator.calculateBill(
        lines: const [
          BillingLineInput(
            description: 'Banner',
            unit: BillingUnit.area,
            unitRate: 80,
            width: 2,
            height: 3,
            pieces: 2,
          ),
        ],
        discount: 10,
        discountIsPercent: true,
      );

      expect(result.lines.single.quantity, 12);
      expect(result.subtotal, 960);
      expect(result.discount, 96);
      expect(result.netTotal, 864);
    });

    test('rejects overpayment and excessive discounts', () {
      expect(
        () => BusinessCalculator.calculateBill(
          lines: const [
            BillingLineInput(
              description: 'Flyer',
              unit: BillingUnit.piece,
              unitRate: 2,
              pieces: 10,
            ),
          ],
          paid: 21,
        ),
        throwsArgumentError,
      );
      expect(
        () => BusinessCalculator.calculateBill(
          lines: const [
            BillingLineInput(
              description: 'Flyer',
              unit: BillingUnit.piece,
              unitRate: 2,
              pieces: 10,
            ),
          ],
          discount: 21,
        ),
        throwsArgumentError,
      );
    });
  });
}
