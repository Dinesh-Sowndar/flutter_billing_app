import 'package:hive/hive.dart';
import '../../domain/entities/customer_entity.dart';

part 'customer_model.g.dart';

@HiveType(typeId: 5)
class CustomerModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String phone;

  @HiveField(3)
  final String userId;

  @HiveField(4)
  final bool pendingSync;

  @HiveField(5, defaultValue: 0.0)
  final double balance; // Added for Customer Ledger

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.userId = '',
    this.pendingSync = false,
    this.balance = 0.0,
  });

  factory CustomerModel.fromEntity(CustomerEntity entity, {String userId = ''}) {
    return CustomerModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      userId: userId,
      pendingSync: entity.pendingSync,
      balance: entity.balance,
    );
  }

  factory CustomerModel.fromFirestore(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      pendingSync: false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'name': name,
        'phone': phone,
        'userId': userId,
        'balance': balance,
      };

  CustomerEntity toEntity() => CustomerEntity(
        id: id,
        name: name,
        phone: phone,
        balance: balance,
        pendingSync: pendingSync,
      );

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? userId,
    bool? pendingSync,
    double? balance,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      userId: userId ?? this.userId,
      pendingSync: pendingSync ?? this.pendingSync,
      balance: balance ?? this.balance,
    );
  }
}
