import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/billing/data/models/transaction_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/customer/data/models/customer_model.dart';
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
  static const String _pendingShopSyncKey = 'pendingShopSync';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<User?>? _authSubscription;

  /// Fired whenever connectivity is restored, so listeners (e.g. BLoC) can
  /// reload products from the freshly-synced Hive store.
  final StreamController<void> onSyncComplete =
      StreamController<void>.broadcast();

  bool _isOnline = false;
  bool get isOnline => _isOnline;
  bool get hasPendingShopSync =>
      HiveDatabase.settingsBox.get(_pendingShopSyncKey, defaultValue: false) ==
      true;

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
        await processPendingDeletes();
        await syncPendingProducts();
        await pullProductsFromFirestore();
        await syncPendingTransactions();
        await pullTransactionsFromFirestore();
        await syncPendingShop();
        await pullShopFromFirestore();
        await pushPendingCustomers();
        await pullCustomersFromFirestore();
        onSyncComplete.add(null);
      }
    });

    _authSubscription = _auth.authStateChanges().listen((User? user) async {
      // When a user logs in and we are online, aggressively pull their latest data
      // into Hive. If a user logs out, they are handled by clearAllData(), but
      // we still emit to trigger bloc reloads (emptying them).
      if (user != null) {
        if (_isOnline) {
          await processPendingDeletes();
          await pullProductsFromFirestore();
          await pullTransactionsFromFirestore();
          await syncPendingShop();
          await pullShopFromFirestore();
          await pullCustomersFromFirestore();
        }
      }
      onSyncComplete.add(null);
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

  DocumentReference<Map<String, dynamic>> get _shopDoc => _firestore
      .collection('users')
      .doc(_userId)
      .collection('shop')
      .doc('details');

  CollectionReference<Map<String, dynamic>> get _customersCollection =>
      _firestore.collection('users').doc(_userId).collection('customers');

  // ---------------------------------------------------------------------------
  // Push a single product to Firestore (used on every write when online).
  // ---------------------------------------------------------------------------
  Future<void> _markAsDeletedLocally(String collection, String id) async {
    final pendingDeletes = List<String>.from(HiveDatabase.settingsBox
        .get('pendingDeletes', defaultValue: <String>[]));
    final entry = '$collection:$id';
    if (!pendingDeletes.contains(entry)) {
      pendingDeletes.add(entry);
      await HiveDatabase.settingsBox.put('pendingDeletes', pendingDeletes);
    }
  }

  Future<void> processPendingDeletes() async {
    if (_userId == null) return;
    final pendingDeletes = List<String>.from(HiveDatabase.settingsBox
        .get('pendingDeletes', defaultValue: <String>[]));
    if (pendingDeletes.isEmpty) return;

    List<String> remaining = [];
    for (final entry in pendingDeletes) {
      try {
        final parts = entry.split(':');
        final collection = parts[0];
        final id = parts[1];
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection(collection)
            .doc(id)
            .delete();
      } catch (_) {
        remaining.add(entry);
      }
    }

    if (remaining.isEmpty) {
      await HiveDatabase.settingsBox.delete('pendingDeletes');
    } else {
      await HiveDatabase.settingsBox.put('pendingDeletes', remaining);
    }
  }

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
      if (_isOnline) {
        await _productsCollection.doc(id).delete();
      } else {
        await _markAsDeletedLocally('products', id);
      }
    } catch (_) {
      await _markAsDeletedLocally('products', id);
    }
  }

  // ---------------------------------------------------------------------------
  // Push all locally pending products to Firestore.
  // ---------------------------------------------------------------------------
  Future<void> syncPendingProducts() async {
    final uid = _userId;
    if (uid == null) return;
    final pending =
        HiveDatabase.productBox.values.where((p) => p.pendingSync).toList();
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
      if (_isOnline) {
        await _transactionsCollection.doc(id).delete();
      } else {
        await _markAsDeletedLocally('transactions', id);
      }
    } catch (_) {
      await _markAsDeletedLocally('transactions', id);
    }
  }

  // ---------------------------------------------------------------------------
  // Push all locally pending transactions to Firestore.
  // ---------------------------------------------------------------------------
  Future<void> syncPendingTransactions() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    final pending =
        HiveDatabase.transactionBox.values.where((t) => t.pendingSync).toList();
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

  // ---------------------------------------------------------------------------
  // Push shop details to Firestore.
  // ---------------------------------------------------------------------------
  Future<void> pushShop(ShopModel model) async {
    final uid = _userId;
    if (uid == null) {
      await markShopPendingSync();
      return;
    }
    try {
      await _shopDoc.set(model.toFirestore(), SetOptions(merge: true));
      await clearPendingShopSync();
    } catch (_) {
      await markShopPendingSync();
    }
  }

  Future<void> markShopPendingSync() async {
    await HiveDatabase.settingsBox.put(_pendingShopSyncKey, true);
  }

  Future<void> clearPendingShopSync() async {
    await HiveDatabase.settingsBox.delete(_pendingShopSyncKey);
  }

  Future<void> syncPendingShop() async {
    final hasPending = HiveDatabase.settingsBox
            .get(_pendingShopSyncKey, defaultValue: false) ==
        true;
    if (!hasPending) return;

    final model = HiveDatabase.shopBox.get('shop_details');
    if (model == null) {
      await clearPendingShopSync();
      return;
    }

    await pushShop(model);
  }

  // ---------------------------------------------------------------------------
  // Pull shop details from Firestore into Hive.
  // ---------------------------------------------------------------------------
  Future<void> pullShopFromFirestore() async {
    if (_userId == null) return;
    try {
      final snapshot = await _shopDoc.get();
      if (snapshot.exists && snapshot.data() != null) {
        final model = ShopModel.fromFirestore(snapshot.data()!);
        await HiveDatabase.shopBox.put('shop_details', model);
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

  // ---------------------------------------------------------------------------
  // Push a single customer to Firestore.
  // ---------------------------------------------------------------------------
  Future<void> pushCustomer(CustomerModel model) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await _customersCollection
          .doc(model.id)
          .set(model.toFirestore(), SetOptions(merge: true));
      final cleared = CustomerModel(
        id: model.id,
        name: model.name,
        phone: model.phone,
        userId: model.userId,
        pendingSync: false,
      );
      await HiveDatabase.customerBox.put(cleared.id, cleared);
    } catch (_) {
      final pending = CustomerModel(
        id: model.id,
        name: model.name,
        phone: model.phone,
        userId: model.userId,
        pendingSync: true,
      );
      await HiveDatabase.customerBox.put(pending.id, pending);
    }
  }

  // ---------------------------------------------------------------------------
  // Delete a customer on Firestore.
  // ---------------------------------------------------------------------------
  Future<void> deleteCustomer(String id) async {
    if (_userId == null) return;
    try {
      if (_isOnline) {
        await _customersCollection.doc(id).delete();
      } else {
        await _markAsDeletedLocally('customers', id);
      }
    } catch (_) {
      await _markAsDeletedLocally('customers', id);
    }
  }

  // ---------------------------------------------------------------------------
  // Push all locally-pending customers to Firestore.
  // ---------------------------------------------------------------------------
  Future<void> pushPendingCustomers() async {
    final pending =
        HiveDatabase.customerBox.values.where((c) => c.pendingSync).toList();
    for (final c in pending) {
      await pushCustomer(c);
    }
  }

  // ---------------------------------------------------------------------------
  // Pull the current user's customers from Firestore into Hive.
  // ---------------------------------------------------------------------------
  Future<void> pullCustomersFromFirestore() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final snapshot = await _customersCollection.get();
      for (final doc in snapshot.docs) {
        final model = CustomerModel.fromFirestore(doc.data());
        await HiveDatabase.customerBox.put(model.id, model);
      }
    } catch (_) {}
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _authSubscription?.cancel();
    onSyncComplete.close();
  }
}
