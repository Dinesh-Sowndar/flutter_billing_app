import 'package:equatable/equatable.dart';

enum UserRole { owner, manager, cashier, production }

enum BillingUnit { piece, area }

enum LedgerEntryType { invoice, payment, expense, adjustment }

class Customer extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double openingBalance;

  const Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.openingBalance = 0,
  });

  @override
  List<Object?> get props => [id, name, phone, address, openingBalance];
}

class Supplier extends Equatable {
  final String id;
  final String name;
  final String phone;
  final double openingBalance;

  const Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.openingBalance = 0,
  });

  @override
  List<Object?> get props => [id, name, phone, openingBalance];
}

class RateCardItem extends Equatable {
  final String id;
  final String name;
  final String category;
  final BillingUnit unit;
  final double rate;
  final double wastagePercent;

  const RateCardItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.rate,
    this.wastagePercent = 0,
  });

  @override
  List<Object?> get props =>
      [id, name, category, unit, rate, wastagePercent];
}

class BillingLineInput {
  final String description;
  final BillingUnit unit;
  final double unitRate;
  final double width;
  final double height;
  final int pieces;
  final double addOnTotal;

  const BillingLineInput({
    required this.description,
    required this.unit,
    required this.unitRate,
    this.width = 0,
    this.height = 0,
    this.pieces = 1,
    this.addOnTotal = 0,
  });
}

class BillingLineTotal {
  final BillingLineInput input;
  final double quantity;
  final double total;

  const BillingLineTotal({
    required this.input,
    required this.quantity,
    required this.total,
  });
}

class BillTotals {
  final List<BillingLineTotal> lines;
  final double subtotal;
  final double discount;
  final double netTotal;
  final double paid;

  const BillTotals({
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.netTotal,
    required this.paid,
  });

  double get due => netTotal - paid;
}

class LedgerEntry extends Equatable {
  final String id;
  final String partyId;
  final LedgerEntryType type;
  final double amount;
  final DateTime createdAt;
  final String reference;
  final String note;

  const LedgerEntry({
    required this.id,
    required this.partyId,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.reference = '',
    this.note = '',
  });

  @override
  List<Object?> get props =>
      [id, partyId, type, amount, createdAt, reference, note];
}

class StockMovement extends Equatable {
  final String id;
  final String productId;
  final double quantity;
  final String unit;
  final String reason;
  final DateTime createdAt;

  const StockMovement({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unit,
    required this.reason,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, productId, quantity, unit, reason, createdAt];
}

class BusinessCalculator {
  const BusinessCalculator._();

  static BillingLineTotal calculateLine(BillingLineInput input) {
    if (input.unitRate < 0 ||
        input.width < 0 ||
        input.height < 0 ||
        input.pieces < 0 ||
        input.addOnTotal < 0) {
      throw ArgumentError('Billing values cannot be negative');
    }

    final quantity = input.unit == BillingUnit.area
        ? input.width * input.height * input.pieces
        : input.pieces.toDouble();
    final total = (quantity * input.unitRate) + input.addOnTotal;
    return BillingLineTotal(input: input, quantity: quantity, total: total);
  }

  static BillTotals calculateBill({
    required List<BillingLineInput> lines,
    double discount = 0,
    bool discountIsPercent = false,
    double paid = 0,
  }) {
    if (discount < 0 || paid < 0) {
      throw ArgumentError('Discount and payment cannot be negative');
    }
    final calculatedLines = lines.map(calculateLine).toList(growable: false);
    final subtotal =
        calculatedLines.fold<double>(0, (sum, line) => sum + line.total);
    final discountAmount =
        discountIsPercent ? subtotal * (discount / 100) : discount;
    if (discountAmount > subtotal) {
      throw ArgumentError('Discount cannot exceed subtotal');
    }
    final netTotal = subtotal - discountAmount;
    if (paid > netTotal) {
      throw ArgumentError('Payment cannot exceed net total');
    }
    return BillTotals(
      lines: calculatedLines,
      subtotal: subtotal,
      discount: discountAmount,
      netTotal: netTotal,
      paid: paid,
    );
  }
}
