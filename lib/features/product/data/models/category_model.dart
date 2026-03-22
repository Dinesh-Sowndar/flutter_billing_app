// ignore_for_file: overridden_fields
import 'package:hive/hive.dart';
import 'package:billing_app/features/product/domain/entities/category.dart';

part 'category_model.g.dart';

@HiveType(typeId: 6)
class CategoryModel extends Category {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final bool pendingSync;

  CategoryModel({
    required this.id,
    required this.name,
    this.pendingSync = false,
  }) : super(
          id: id,
          name: name,
          pendingSync: pendingSync,
        );

  factory CategoryModel.fromEntity(Category category) {
    return CategoryModel(
      id: category.id,
      name: category.name,
      pendingSync: category.pendingSync,
    );
  }

  factory CategoryModel.fromFirestore(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      pendingSync: false,
    );
  }

  Map<String, dynamic> toFirestore(String userId) => {
        'id': id,
        'name': name,
        'userId': userId,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  Category toEntity() {
    return Category(
      id: id,
      name: name,
      pendingSync: pendingSync,
    );
  }
}
