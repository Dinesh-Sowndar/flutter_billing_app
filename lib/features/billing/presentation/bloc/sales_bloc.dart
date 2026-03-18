import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/billing_repository.dart';
import '../../data/models/transaction_model.dart';

part 'sales_event.dart';
part 'sales_state.dart';

class SalesBloc extends Bloc<SalesEvent, SalesState> {
  final BillingRepository billingRepository;

  SalesBloc({required this.billingRepository}) : super(const SalesState()) {
    on<LoadSalesEvent>(_onLoadSales);
  }

  void _onLoadSales(LoadSalesEvent event, Emitter<SalesState> emit) {
    emit(state.copyWith(status: SalesStatus.loading));
    try {
      final transactions = billingRepository.getAllTransactions();

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Calculate start of week (assuming Monday is start of week)
      final daysSinceMonday = now.weekday - 1;
      final startOfWeek = startOfDay.subtract(Duration(days: daysSinceMonday));

      // Calculate start of month
      final startOfMonth = DateTime(now.year, now.month, 1);

      double daily = 0;
      double dailyPending = 0;
      double weekly = 0;
      double weeklyPending = 0;
      double monthly = 0;
      double monthlyPending = 0;

      for (var t in transactions) {
        final isPaymentOnly = t.items.isEmpty && t.amountPaid > 0;
        final paidAtSale = t.amountPaid.clamp(0.0, t.totalAmount).toDouble();
        final txPendingDelta = isPaymentOnly
            ? -t.amountPaid
            : (t.totalAmount - paidAtSale).clamp(0.0, t.totalAmount).toDouble();
        if (t.date.isAfter(startOfDay) || t.date.isAtSameMomentAs(startOfDay)) {
          daily += t.totalAmount;
          dailyPending += txPendingDelta;
        }
        if (t.date.isAfter(startOfWeek) ||
            t.date.isAtSameMomentAs(startOfWeek)) {
          weekly += t.totalAmount;
          weeklyPending += txPendingDelta;
        }
        if (t.date.isAfter(startOfMonth) ||
            t.date.isAtSameMomentAs(startOfMonth)) {
          monthly += t.totalAmount;
          monthlyPending += txPendingDelta;
        }
      }

      dailyPending = dailyPending < 0 ? 0 : dailyPending;
      weeklyPending = weeklyPending < 0 ? 0 : weeklyPending;
      monthlyPending = monthlyPending < 0 ? 0 : monthlyPending;

      // Sort transactions by date descending
      transactions.sort((a, b) => b.date.compareTo(a.date));
      // Take top 10
      final recent = transactions.take(10).toList();

      emit(state.copyWith(
        status: SalesStatus.success,
        dailySales: daily,
        dailyPending: dailyPending,
        weeklySales: weekly,
        weeklyPending: weeklyPending,
        monthlySales: monthly,
        monthlyPending: monthlyPending,
        recentTransactions: recent,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SalesStatus.error,
        error: "Failed to load sales data: $e",
      ));
    }
  }
}
