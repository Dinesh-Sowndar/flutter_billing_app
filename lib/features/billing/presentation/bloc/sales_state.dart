part of 'sales_bloc.dart';

enum SalesStatus { initial, loading, success, error }

class SalesState extends Equatable {
  final SalesStatus status;
  final double dailySales;
  final double dailyPending;
  final double weeklySales;
  final double weeklyPending;
  final double monthlySales;
  final double monthlyPending;
  final List<TransactionModel> recentTransactions;
  final String? error;

  const SalesState({
    this.status = SalesStatus.initial,
    this.dailySales = 0.0,
    this.dailyPending = 0.0,
    this.weeklySales = 0.0,
    this.weeklyPending = 0.0,
    this.monthlySales = 0.0,
    this.monthlyPending = 0.0,
    this.recentTransactions = const [],
    this.error,
  });

  SalesState copyWith({
    SalesStatus? status,
    double? dailySales,
    double? dailyPending,
    double? weeklySales,
    double? weeklyPending,
    double? monthlySales,
    double? monthlyPending,
    List<TransactionModel>? recentTransactions,
    String? error,
    bool clearError = false,
  }) {
    return SalesState(
      status: status ?? this.status,
      dailySales: dailySales ?? this.dailySales,
      dailyPending: dailyPending ?? this.dailyPending,
      weeklySales: weeklySales ?? this.weeklySales,
      weeklyPending: weeklyPending ?? this.weeklyPending,
      monthlySales: monthlySales ?? this.monthlySales,
      monthlyPending: monthlyPending ?? this.monthlyPending,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        status,
        dailySales,
        dailyPending,
        weeklySales,
        weeklyPending,
        monthlySales,
        monthlyPending,
        recentTransactions,
        error,
      ];
}
