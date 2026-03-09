import '../../data/models/transaction_model.dart';
import '../../../../core/data/hive_database.dart';

class BillingRepository {
  Future<void> saveTransaction(TransactionModel transaction) async {
    await HiveDatabase.transactionBox.put(transaction.id, transaction);
  }

  List<TransactionModel> getAllTransactions() {
    return HiveDatabase.transactionBox.values.toList();
  }
}
