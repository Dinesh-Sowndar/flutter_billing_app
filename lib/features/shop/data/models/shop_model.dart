// ignore_for_file: overridden_fields
import 'package:hive/hive.dart';
import '../../domain/entities/shop.dart';

part 'shop_model.g.dart';

@HiveType(typeId: 1)
class ShopModel extends Shop {
  @override
  @HiveField(0)
  final String name;
  @override
  @HiveField(1)
  final String addressLine1;
  @override
  @HiveField(2)
  final String addressLine2;
  @override
  @HiveField(3)
  final String phoneNumber;
  @override
  @HiveField(4)
  final String upiId;
  @override
  @HiveField(5)
  final String footerText;
  @override
  @HiveField(6, defaultValue: '')
  final String gstNumber;

  const ShopModel({
    required this.name,
    required this.addressLine1,
    required this.addressLine2,
    required this.phoneNumber,
    required this.upiId,
    required this.footerText,
    this.gstNumber = '',
  }) : super(
          name: name,
          addressLine1: addressLine1,
          addressLine2: addressLine2,
          phoneNumber: phoneNumber,
          upiId: upiId,
          footerText: footerText,
          gstNumber: gstNumber,
        );

  factory ShopModel.fromEntity(Shop shop) {
    return ShopModel(
      name: shop.name,
      addressLine1: shop.addressLine1,
      addressLine2: shop.addressLine2,
      phoneNumber: shop.phoneNumber,
      upiId: shop.upiId,
      footerText: shop.footerText,
      gstNumber: shop.gstNumber,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'phoneNumber': phoneNumber,
      'upiId': upiId,
      'footerText': footerText,
      'gstNumber': gstNumber,
    };
  }

  factory ShopModel.fromFirestore(Map<String, dynamic> data) {
    return ShopModel(
      name: data['name'] ?? '',
      addressLine1: data['addressLine1'] ?? '',
      addressLine2: data['addressLine2'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      upiId: data['upiId'] ?? '',
      footerText: data['footerText'] ?? '',
      gstNumber: data['gstNumber'] ?? '',
    );
  }

  Shop toEntity() => this;
}
