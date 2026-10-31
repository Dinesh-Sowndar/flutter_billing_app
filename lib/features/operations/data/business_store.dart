import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class BusinessStore {
  static const boxName = 'business_records';
  static const uuid = Uuid();

  Box get _box => Hive.box(boxName);

  Future<String> save(String collection, Map<String, dynamic> record) async {
    final id = record['id'] as String? ?? uuid.v4();
    await _box.put('$collection:$id', {
      ...record,
      'collection': collection,
      'id': id,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return id;
  }

  List<Map<String, dynamic>> all(String collection) {
    return _box.values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((value) => value['collection'] == collection)
        .toList(growable: false);
  }

  Future<void> append(String collection, Map<String, dynamic> record) {
    return save(collection, {...record, 'collection': collection});
  }
}
