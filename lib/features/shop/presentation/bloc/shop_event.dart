part of 'shop_bloc.dart';

abstract class ShopEvent extends Equatable {
  const ShopEvent();
  @override
  List<Object> get props => [];
}

class LoadShopEvent extends ShopEvent {}

class UpdateShopEvent extends ShopEvent {
  final Shop shop;
  const UpdateShopEvent(this.shop);
  @override
  List<Object> get props => [shop];
}
