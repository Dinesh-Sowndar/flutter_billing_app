import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../domain/erp_models.dart';

class ErpRepository {
  ErpRepository(this._box);
  final Box<dynamic> _box;
  static const _uuid = Uuid();

  UserRecord currentUser = const UserRecord(id: 'local-admin', name: 'Local Administrator', email: 'admin@alnoor.local', role: UserRole.admin);

  bool canAccess(UserRole role) => currentUser.role == UserRole.admin || currentUser.role == role;

  Future<String> saveInvoice(InvoiceRecord invoice) async {
    await _box.put('invoice:${invoice.id}', {'id': invoice.id, 'number': invoice.number, 'customerId': invoice.customerId, 'total': invoice.total, 'createdAt': invoice.createdAt.toIso8601String(), 'notes': invoice.notes});
    return invoice.id;
  }

  Future<String> saveExpense({required String category, required double amount, String notes = ''}) async {
    final id = _uuid.v4();
    await _box.put('expense:$id', {'id': id, 'category': category, 'amount': amount, 'notes': notes, 'createdAt': DateTime.now().toIso8601String()});
    return id;
  }

  int count(String prefix) => _box.keys.where((key) => key.toString().startsWith('$prefix:')).length;
}
