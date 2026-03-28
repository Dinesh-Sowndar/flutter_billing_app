import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/transaction_model.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/services/sync_service.dart';

class BillingRepository {
  final SyncService syncService;

  BillingRepository({required this.syncService});

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Saves to Hive first (offline-first), then pushes to Firestore in the
  /// background so the UI is never blocked by a network call.
  Future<void> saveTransaction(TransactionModel transaction) async {
    final uid = _userId ?? '';
    // Always save with pendingSync: true first for instant local persistence.
    final model = transaction.copyWith(
      userId: uid,
      pendingSync: true,
    );
    await HiveDatabase.transactionBox.put(model.id, model);

    // Fire-and-forget: push to Firestore in the background.
    if (syncService.isOnline && uid.isNotEmpty) {
      syncService.pushTransaction(model); // no await — non-blocking
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
