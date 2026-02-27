part of 'shop_bloc.dart';

abstract class ShopState extends Equatable {
  const ShopState();
  @override
  List<Object> get props => [];
}

class ShopInitial extends ShopState {}

class ShopLoading extends ShopState {}

class ShopLoaded extends ShopState {
  final Shop shop;
  const ShopLoaded(this.shop);
  @override
  List<Object> get props => [shop];
}

class ShopError extends ShopState {
  final String message;
  const ShopError(this.message);
  @override
  List<Object> get props => [message];
}

class ShopOperationSuccess extends ShopState {}
