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
  final int quantity;

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
  /// Empty string for legacy records written before auth was added.
  @HiveField(4)
  final String userId;

  /// True when the record has not yet been pushed to Firestore.
  @HiveField(5)
  final bool pendingSync;

  TransactionModel({
    required this.id,
    required this.date,
    required this.totalAmount,
    required this.items,
    this.userId = '',
    this.pendingSync = false,
  });

  factory TransactionModel.fromFirestore(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return TransactionModel(
      id: map['id'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      userId: map['userId'] as String? ?? '',
      pendingSync: false,
      items: rawItems
          .map((i) => TransactionItemModel(
                productId: i['productId'] as String? ?? '',
                productName: i['productName'] as String? ?? '',
                price: (i['price'] as num?)?.toDouble() ?? 0.0,
                quantity: (i['quantity'] as num?)?.toInt() ?? 1,
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
  }) {
    return TransactionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      userId: userId ?? this.userId,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
