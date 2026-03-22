import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String name;
  final bool pendingSync;

  const Category({
    required this.id,
    required this.name,
    this.pendingSync = false,
  });

  Category copyWith({
    String? id,
    String? name,
    bool? pendingSync,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  @override
  List<Object?> get props => [id, name, pendingSync];
}
