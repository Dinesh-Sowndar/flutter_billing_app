import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 2)
class TransactionItemModel {
  @HiveField(0)
  final String productId;

  @HiveField(1)
  final String productName;

  @HiveField(2)
  final double price;

  @HiveField(3)
  final double quantity;

  @HiveField(4)
  final double total;

  TransactionItemModel({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.total,
  });
}

@HiveType(typeId: 3)
class TransactionModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final double totalAmount;

  @HiveField(3)
  final List<TransactionItemModel> items;

  /// UID of the Firebase user who created this transaction.
  @HiveField(4)
  final String userId;

  /// True when the record has not yet been pushed to Firestore.
  @HiveField(5)
  final bool pendingSync;

  /// Optional: ID of the customer this transaction is linked to.
  @HiveField(6)
  final String customerId;

  /// Optional: Display name of the customer this transaction is linked to.
  @HiveField(7)
  final String customerName;

  /// The amount paid by the customer at the time of transaction.
  @HiveField(8, defaultValue: 0.0)
  final double amountPaid;

  /// The payment method used.
  @HiveField(9, defaultValue: 'cash')
  final String paymentMethod;

  /// GST rate applied to this transaction (0 = no GST).
  @HiveField(10, defaultValue: 0.0)
  final double gstRate;

  /// CGST amount (Central GST — half of total GST).
  @HiveField(11, defaultValue: 0.0)
  final double cgstAmount;

  /// SGST amount (State GST — half of total GST).
  @HiveField(12, defaultValue: 0.0)
  final double sgstAmount;

  /// GSTIN of the shop at the time of transaction.
  @HiveField(13, defaultValue: '')
  final String gstNumber;

  TransactionModel({
    required this.id,
    required this.date,
    required this.totalAmount,
    required this.items,
    this.userId = '',
    this.pendingSync = false,
    this.customerId = '',
    this.customerName = '',
    this.amountPaid = 0.0,
    this.paymentMethod = 'cash',
    this.gstRate = 0.0,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.gstNumber = '',
  });

  factory TransactionModel.fromFirestore(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return TransactionModel(
      id: map['id'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      userId: map['userId'] as String? ?? '',
      pendingSync: false,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ??
          (map['totalAmount'] as num?)?.toDouble() ??
          0.0,
      paymentMethod: map['paymentMethod'] as String? ?? 'cash',
      gstRate: (map['gstRate'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (map['cgstAmount'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (map['sgstAmount'] as num?)?.toDouble() ?? 0.0,
      gstNumber: map['gstNumber'] as String? ?? '',
      items: rawItems
          .map((i) => TransactionItemModel(
                productId: i['productId'] as String? ?? '',
                productName: i['productName'] as String? ?? '',
                price: (i['price'] as num?)?.toDouble() ?? 0.0,
                quantity: (i['quantity'] as num?)?.toDouble() ?? 1,
                total: (i['total'] as num?)?.toDouble() ?? 0.0,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'date': Timestamp.fromDate(date),
        'totalAmount': totalAmount,
        'userId': userId,
        'customerId': customerId,
        'customerName': customerName,
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod,
        'gstRate': gstRate,
        'cgstAmount': cgstAmount,
        'sgstAmount': sgstAmount,
        'gstNumber': gstNumber,
        'items': items
            .map((i) => {
                  'productId': i.productId,
                  'productName': i.productName,
                  'price': i.price,
                  'quantity': i.quantity,
                  'total': i.total,
                })
            .toList(),
      };

  TransactionModel copyWith({
    String? id,
    DateTime? date,
    double? totalAmount,
    List<TransactionItemModel>? items,
    String? userId,
    bool? pendingSync,
    String? customerId,
    String? customerName,
    double? amountPaid,
    String? paymentMethod,
    double? gstRate,
    double? cgstAmount,
    double? sgstAmount,
    String? gstNumber,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      userId: userId ?? this.userId,
      pendingSync: pendingSync ?? this.pendingSync,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      gstRate: gstRate ?? this.gstRate,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      gstNumber: gstNumber ?? this.gstNumber,
    );
  }
}
