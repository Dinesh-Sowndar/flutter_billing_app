/// Small, dependency-free billing primitives for the ERP.
///
/// Amounts are stored as integer poisha (1/100 of a taka). This keeps all
/// calculations deterministic and avoids using binary floating point for money.
library billing_core;

enum BillingUnit { squareFoot, piece }

class Bdt implements Comparable<Bdt> {
  final int poisha;

  const Bdt.fromPoisha(this.poisha);

  factory Bdt.fromTaka(String value) {
    final text = value.trim();
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d{0,2}))?$').firstMatch(text);
    if (match == null) {
      throw FormatException('Invalid BDT amount: $value');
    }
    final sign = match.group(1) == '-' ? -1 : 1;
    final taka = int.parse(match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    return Bdt.fromPoisha(sign * (taka * 100 + int.parse(fraction)));
  }

  static const zero = Bdt.fromPoisha(0);

  Bdt operator +(Bdt other) => Bdt.fromPoisha(poisha + other.poisha);
  Bdt operator -(Bdt other) => Bdt.fromPoisha(poisha - other.poisha);
  Bdt operator -() => Bdt.fromPoisha(-poisha);
  Bdt operator *(int multiplier) => Bdt.fromPoisha(poisha * multiplier);
  bool operator <(Bdt other) => poisha < other.poisha;
  bool operator <=(Bdt other) => poisha <= other.poisha;
  bool operator >(Bdt other) => poisha > other.poisha;
  bool operator >=(Bdt other) => poisha >= other.poisha;

  String get takaString {
    final sign = poisha < 0 ? '-' : '';
    final absolute = poisha.abs();
    return '$sign${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
  }

  @override
  String toString() => '৳$takaString';

  @override
  int compareTo(Bdt other) => poisha.compareTo(other.poisha);

  @override
  bool operator ==(Object other) =>
      other is Bdt && other.poisha == poisha;

  @override
  int get hashCode => poisha.hashCode;
}

enum Lamination { none, gloss, matte }
enum BoardPasting { none, single, double }

class PricingAddOns {
  final Lamination lamination;
  final Bdt laminationPerUnit;
  final BoardPasting boardPasting;
  final Bdt boardPastingPerUnit;
  final Bdt lightboxPerUnit;

  const PricingAddOns({
    this.lamination = Lamination.none,
    this.laminationPerUnit = Bdt.zero,
    this.boardPasting = BoardPasting.none,
    this.boardPastingPerUnit = Bdt.zero,
    this.lightboxPerUnit = Bdt.zero,
  });

  Bdt get totalPerUnit =>
      laminationPerUnit + boardPastingPerUnit + lightboxPerUnit;
}

class BillingLine {
  final String description;
  final BillingUnit unit;
  final int quantity;
  final Bdt unitPrice;
  final int? widthInches;
  final int? heightInches;
  final PricingAddOns addOns;

  const BillingLine({
    required this.description,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.widthInches,
    this.heightInches,
    this.addOns = const PricingAddOns(),
  })  : assert(quantity > 0),
        assert(unitPrice.poisha >= 0),
        assert(widthInches == null || widthInches > 0),
        assert(heightInches == null || heightInches > 0);

  factory BillingLine.squareFoot({
    required String description,
    required int quantity,
    required int widthInches,
    required int heightInches,
    required Bdt pricePerSquareFoot,
    PricingAddOns addOns = const PricingAddOns(),
  }) {
    return BillingLine(
      description: description,
      unit: BillingUnit.squareFoot,
      quantity: quantity,
      unitPrice: pricePerSquareFoot,
      widthInches: widthInches,
      heightInches: heightInches,
      addOns: addOns,
    );
  }

  factory BillingLine.pieces({
    required String description,
    required int quantity,
    required Bdt pricePerPiece,
    PricingAddOns addOns = const PricingAddOns(),
  }) {
    return BillingLine(
      description: description,
      unit: BillingUnit.piece,
      quantity: quantity,
      unitPrice: pricePerPiece,
      addOns: addOns,
    );
  }

  /// Area is represented as a numerator over 144, rather than a double.
  int get areaNumerator =>
      unit == BillingUnit.squareFoot ? widthInches! * heightInches! * quantity : 0;

  int get areaDenominator => 144;

  Bdt get baseAmount {
    if (unit == BillingUnit.piece) return unitPrice * quantity;
    return _rateTimesFraction(unitPrice, areaNumerator, areaDenominator);
  }

  Bdt get addOnAmount {
    if (unit == BillingUnit.piece) {
      return addOns.totalPerUnit * quantity;
    }
    return _rateTimesFraction(
      addOns.totalPerUnit,
      areaNumerator,
      areaDenominator,
    );
  }

  Bdt get total => baseAmount + addOnAmount;

  static Bdt _rateTimesFraction(Bdt rate, int numerator, int denominator) {
    final product = rate.poisha * numerator;
    final rounded = (product + denominator ~/ 2) ~/ denominator;
    return Bdt.fromPoisha(rounded);
  }
}

class InvoiceTotal {
  final List<BillingLine> lines;

  InvoiceTotal(Iterable<BillingLine> lines)
      : lines = List.unmodifiable(lines);

  Bdt get total => lines.fold(Bdt.zero, (sum, line) => sum + line.total);
}

enum PaymentMethod { cash, bKash, nagad, rocket, bankTransfer }

class Payment {
  final PaymentMethod method;
  final Bdt amount;

  const Payment({required this.method, required this.amount})
      : assert(amount.poisha >= 0);
}

class PaymentSettlement {
  final Bdt due;
  final List<Payment> payments;

  PaymentSettlement({required this.due, required Iterable<Payment> payments})
      : assert(due.poisha >= 0),
        payments = List.unmodifiable(payments);

  Bdt get paid => payments.fold(Bdt.zero, (sum, payment) => sum + payment.amount);
  Bdt get outstanding => paid < due ? due - paid : Bdt.zero;
  Bdt get change => paid > due ? paid - due : Bdt.zero;
  bool get isPaid => outstanding == Bdt.zero;
}

enum DocumentType { invoice, challan, quotation }

extension DocumentTypeCode on DocumentType {
  String get code {
    switch (this) {
      case DocumentType.invoice:
        return 'INV';
      case DocumentType.challan:
        return 'CH';
      case DocumentType.quotation:
        return 'QT';
    }
  }
}

class DocumentNumberGenerator {
  final Map<String, int> _nextByYearAndType;

  DocumentNumberGenerator({Map<String, int>? nextByYearAndType})
      : _nextByYearAndType = Map<String, int>.from(nextByYearAndType ?? {});

  String next(DocumentType type, int year) {
    if (year < 1) throw ArgumentError.value(year, 'year');
    final key = '${type.code}:$year';
    final sequence = _nextByYearAndType[key] ?? 1;
    _nextByYearAndType[key] = sequence + 1;
    return '${type.code}/$year/${sequence.toString().padLeft(4, '0')}';
  }
}
