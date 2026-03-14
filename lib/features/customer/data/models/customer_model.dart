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

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.userId = '',
    this.pendingSync = false,
  });

  factory CustomerModel.fromEntity(CustomerEntity entity, {String userId = ''}) {
    return CustomerModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      userId: userId,
      pendingSync: entity.pendingSync,
    );
  }

  factory CustomerModel.fromFirestore(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      pendingSync: false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'name': name,
        'phone': phone,
        'userId': userId,
      };

  CustomerEntity toEntity() => CustomerEntity(
        id: id,
        name: name,
        phone: phone,
        pendingSync: pendingSync,
      );

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? userId,
    bool? pendingSync,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      userId: userId ?? this.userId,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
