enum UserRole { admin, accountant, operator }
enum PaymentMethod { cash, bKash, nagad, rocket, bankTransfer }
enum DocumentType { invoice, challan, quotation }
enum PrintMode { withPad, withoutPad }

class UserRecord {
  const UserRecord({required this.id, required this.name, required this.email, required this.role, this.active = true});
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool active;
}

class CustomerRecord {
  const CustomerRecord({required this.id, required this.name, this.phone = '', this.address = ''});
  final String id;
  final String name;
  final String phone;
  final String address;
}

class InventoryRecord {
  const InventoryRecord({required this.id, required this.name, required this.sku, required this.unit, required this.stock, required this.costPrice, required this.sellingPrice, this.reorderLevel = 0});
  final String id;
  final String name;
  final String sku;
  final String unit;
  final double stock;
  final double costPrice;
  final double sellingPrice;
  final double reorderLevel;
}

class InvoiceRecord {
  const InvoiceRecord({required this.id, required this.number, required this.customerId, required this.total, required this.createdAt, this.notes = ''});
  final String id;
  final String number;
  final String customerId;
  final double total;
  final DateTime createdAt;
  final String notes;
}

class StockPurchaseRecord {
  const StockPurchaseRecord({required this.id, required this.supplier, required this.total, required this.createdAt});
  final String id;
  final String supplier;
  final double total;
  final DateTime createdAt;
}

class JobOrderRecord {
  const JobOrderRecord({required this.id, required this.customerId, required this.description, required this.status, required this.dueDate});
  final String id;
  final String customerId;
  final String description;
  final String status;
  final DateTime dueDate;
}

class WastageRecord {
  const WastageRecord({required this.id, required this.inventoryId, required this.quantity, required this.reason, required this.createdAt});
  final String id;
  final String inventoryId;
  final double quantity;
  final String reason;
  final DateTime createdAt;
}

class ExpenseRecord {
  const ExpenseRecord({required this.id, required this.category, required this.amount, required this.createdAt, this.notes = ''});
  final String id;
  final String category;
  final double amount;
  final DateTime createdAt;
  final String notes;
}

class CashRegisterRecord {
  const CashRegisterRecord({required this.id, required this.openedAt, required this.openingBalance, this.closingBalance});
  final String id;
  final DateTime openedAt;
  final double openingBalance;
  final double? closingBalance;
}
