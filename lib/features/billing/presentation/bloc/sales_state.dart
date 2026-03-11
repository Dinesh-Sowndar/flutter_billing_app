part of 'sales_bloc.dart';

enum SalesStatus { initial, loading, success, error }

class SalesState extends Equatable {
  final SalesStatus status;
  final double dailySales;
  final double weeklySales;
  final double monthlySales;
  final List<TransactionModel> recentTransactions;
  final String? error;

  const SalesState({
    this.status = SalesStatus.initial,
    this.dailySales = 0.0,
    this.weeklySales = 0.0,
    this.monthlySales = 0.0,
    this.recentTransactions = const [],
    this.error,
  });

  SalesState copyWith({
    SalesStatus? status,
    double? dailySales,
    double? weeklySales,
    double? monthlySales,
    List<TransactionModel>? recentTransactions,
    String? error,
    bool clearError = false,
  }) {
    return SalesState(
      status: status ?? this.status,
      dailySales: dailySales ?? this.dailySales,
      weeklySales: weeklySales ?? this.weeklySales,
      monthlySales: monthlySales ?? this.monthlySales,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        status,
        dailySales,
        weeklySales,
        monthlySales,
        recentTransactions,
        error,
      ];
}
