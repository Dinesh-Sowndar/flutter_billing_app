import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/billing/data/models/transaction_model.dart';
import '../data/hive_database.dart';

/// Syncs Hive (local) ↔ Firestore (cloud) whenever connectivity changes.
///
/// Strategy:
///   • Every write goes to Hive first (offline-first).
///   • When online, the write is also pushed to Firestore immediately.
///   • If offline, `pendingSync = true` is set on the Hive record.
///   • When connectivity is restored, all pending records are pushed and any
///     new records from Firestore are pulled into Hive.
class SyncService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Fired whenever connectivity is restored, so listeners (e.g. BLoC) can
  /// reload products from the freshly-synced Hive store.
  final StreamController<void> onSyncComplete =
      StreamController<void>.broadcast();

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  SyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Connectivity? connectivity,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _connectivity = connectivity ?? Connectivity();

  /// Start listening for connectivity changes.
  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _resultsHaveConnection(results);

    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final wasOnline = _isOnline;
      _isOnline = _resultsHaveConnection(results);
      if (!wasOnline && _isOnline) {
        await syncPendingProducts();
        await pullProductsFromFirestore();
        await syncPendingTransactions();
        await pullTransactionsFromFirestore();
        onSyncComplete.add(null);
      }
    });
  }

  bool _resultsHaveConnection(List<ConnectivityResult> results) =>
      results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _productsCollection =>
      _firestore.collection('users').doc(_userId).collection('products');

  CollectionReference<Map<String, dynamic>> get _transactionsCollection =>
      _firestore.collection('users').doc(_userId).collection('transactions');

  // ---------------------------------------------------------------------------
  // Push a single product to Firestore (used on every write when online).
  // ---------------------------------------------------------------------------
  Future<void> pushProduct(ProductModel model) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await _productsCollection
          .doc(model.id)
          .set(model.toFirestore(uid), SetOptions(merge: true));
      // Clear pendingSync flag locally.
      final clearedModel = ProductModel(
        id: model.id,
        name: model.name,
        barcode: model.barcode,
        price: model.price,
        stock: model.stock,
        unitIndex: model.unitIndex,
        pendingSync: false,
      );
      await HiveDatabase.productBox.put(clearedModel.id, clearedModel);
    } catch (_) {
      // If push fails, mark as pending so it's retried later.
      _markPending(model);
    }
  }

  // ---------------------------------------------------------------------------
  // Delete a product on Firestore.
  // ---------------------------------------------------------------------------
  Future<void> deleteProduct(String id) async {
    if (_userId == null) return;
    try {
      await _productsCollection.doc(id).delete();
    } catch (_) {
      // Deletion failures are not queued; the record is already gone locally.
    }
  }

  // ---------------------------------------------------------------------------
  // Push all locally pending products to Firestore.
  // ---------------------------------------------------------------------------
  Future<void> syncPendingProducts() async {
    final uid = _userId;
    if (uid == null) return;
    final pending = HiveDatabase.productBox.values
        .where((p) => p.pendingSync)
        .toList();
    for (final model in pending) {
      try {
        await _productsCollection
            .doc(model.id)
            .set(model.toFirestore(uid), SetOptions(merge: true));
        final clearedModel = ProductModel(
          id: model.id,
          name: model.name,
          barcode: model.barcode,
          price: model.price,
          stock: model.stock,
          unitIndex: model.unitIndex,
          pendingSync: false,
        );
        await HiveDatabase.productBox.put(clearedModel.id, clearedModel);
      } catch (_) {
        // Leave as pending; will be retried on next sync.
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Pull all products for the current user from Firestore into Hive.
  // Firestore is the source of truth when online.
  // ---------------------------------------------------------------------------
  Future<void> pullProductsFromFirestore() async {
    if (_userId == null) return;
    try {
      final snapshot = await _productsCollection.get();
      for (final doc in snapshot.docs) {
        final model = ProductModel.fromFirestore(doc.data());
        // Only overwrite if Firestore version isn't older than local pending.
        final local = HiveDatabase.productBox.get(model.id);
        if (local == null || !local.pendingSync) {
          await HiveDatabase.productBox.put(model.id, model);
        }
      }
    } catch (_) {
      // Ignore pull errors; local data is still valid.
    }
  }

  // ---------------------------------------------------------------------------
  // Push a single transaction to Firestore.
  // ---------------------------------------------------------------------------
  Future<void> pushTransaction(TransactionModel model) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    try {
      await _transactionsCollection
          .doc(model.id)
          .set(model.toFirestore(), SetOptions(merge: true));
      // Clear the pendingSync flag in Hive.
      await HiveDatabase.transactionBox
          .put(model.id, model.copyWith(pendingSync: false));
    } catch (_) {
      // Mark as pending so it's retried on next sync.
      await HiveDatabase.transactionBox
          .put(model.id, model.copyWith(pendingSync: true));
    }
  }

  // ---------------------------------------------------------------------------
  // Delete a transaction on Firestore.
  // ---------------------------------------------------------------------------
  Future<void> deleteTransaction(String id) async {
    if (_userId == null) return;
    try {
      await _transactionsCollection.doc(id).delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Push all locally pending transactions to Firestore.
  // ---------------------------------------------------------------------------
  Future<void> syncPendingTransactions() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    final pending = HiveDatabase.transactionBox.values
        .where((t) => t.pendingSync)
        .toList();
    for (final model in pending) {
      try {
        await _transactionsCollection
            .doc(model.id)
            .set(model.toFirestore(), SetOptions(merge: true));
        await HiveDatabase.transactionBox
            .put(model.id, model.copyWith(pendingSync: false));
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Pull all transactions for the current user from Firestore into Hive.
  // ---------------------------------------------------------------------------
  Future<void> pullTransactionsFromFirestore() async {
    if (_userId == null) return;
    try {
      final snapshot = await _transactionsCollection.get();
      for (final doc in snapshot.docs) {
        final model = TransactionModel.fromFirestore(doc.data());
        final local = HiveDatabase.transactionBox.get(model.id);
        // Don't overwrite local records that are pending upload.
        if (local == null || !local.pendingSync) {
          await HiveDatabase.transactionBox.put(model.id, model);
        }
      }
    } catch (_) {}
  }

  void _markPending(ProductModel model) {
    final updated = ProductModel(
      id: model.id,
      name: model.name,
      barcode: model.barcode,
      price: model.price,
      stock: model.stock,
      unitIndex: model.unitIndex,
      pendingSync: true,
    );
    HiveDatabase.productBox.put(updated.id, updated);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    onSyncComplete.close();
  }
}
