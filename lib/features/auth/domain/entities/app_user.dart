import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String id;
  final String email;
  final String status;
  final bool deleted;

  const AppUser({
    required this.id,
    required this.email,
    this.status = 'active',
    this.deleted = false,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? status,
    bool? deleted,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      status: status ?? this.status,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  List<Object?> get props => [id, email, status, deleted];
}
