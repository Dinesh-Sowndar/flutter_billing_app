import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/transaction_model.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/services/sync_service.dart';

class BillingRepository {
  final SyncService syncService;

  BillingRepository({required this.syncService});

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Saves to Hive first (offline-first), then pushes to Firestore if online.
  Future<void> saveTransaction(TransactionModel transaction) async {
    final uid = _userId ?? '';
    final model = transaction.copyWith(
      userId: uid,
      pendingSync: !syncService.isOnline,
    );
    await HiveDatabase.transactionBox.put(model.id, model);
    if (syncService.isOnline && uid.isNotEmpty) {
      await syncService.pushTransaction(model);
    }
  }

  /// Returns only transactions belonging to the currently logged-in user.
  /// Legacy records with empty userId are included for backward compatibility.
  List<TransactionModel> getAllTransactions() {
    final uid = _userId;
    if (uid == null) return [];
    return HiveDatabase.transactionBox.values
        .where((t) => t.userId == uid || t.userId.isEmpty)
        .toList();
  }
}
