import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/data/hive_database.dart';
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

      // Keep period pending non-negative first.
      dailyPending = dailyPending < 0 ? 0 : dailyPending;
      weeklyPending = weeklyPending < 0 ? 0 : weeklyPending;
      monthlyPending = monthlyPending < 0 ? 0 : monthlyPending;

      // Final guard: if all customer dues are currently cleared,
      // dashboard due chips should not show stale period-level pending.
      final currentOutstandingDue = HiveDatabase.customerBox.values
          .fold<double>(
              0.0,
              (sum, customer) =>
                  sum + (customer.balance > 0 ? customer.balance : 0.0));

      if (currentOutstandingDue <= 0) {
        dailyPending = 0;
        weeklyPending = 0;
        monthlyPending = 0;
      }

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
