import 'package:hive/hive.dart';
import '../../domain/entities/supplier_entity.dart';

part 'supplier_model.g.dart';

@HiveType(typeId: 7)
class SupplierModel extends HiveObject {
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
  final double balance;

  SupplierModel({
    required this.id,
    required this.name,
    required this.phone,
    this.userId = '',
    this.pendingSync = false,
    this.balance = 0.0,
  });

  factory SupplierModel.fromEntity(SupplierEntity entity, {String userId = ''}) {
    return SupplierModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      userId: userId,
      pendingSync: entity.pendingSync,
      balance: entity.balance,
    );
  }

  factory SupplierModel.fromFirestore(Map<String, dynamic> map) {
    return SupplierModel(
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

  SupplierEntity toEntity() => SupplierEntity(
        id: id,
        name: name,
        phone: phone,
        balance: balance,
        pendingSync: pendingSync,
      );

  SupplierModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? userId,
    bool? pendingSync,
    double? balance,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      userId: userId ?? this.userId,
      pendingSync: pendingSync ?? this.pendingSync,
      balance: balance ?? this.balance,
    );
  }
}
