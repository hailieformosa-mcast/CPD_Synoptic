import 'package:hive/hive.dart';

class LocalStorageService {
  static const String boxName = 'shopping_list';

  Future<void> addItem(String name, String quantity) async {
    final box = await Hive.openBox(boxName);
    await box.add({'name': name, 'quantity': quantity});
  }

  Future<List<Map<String, String>>> getItems() async {
    final box = await Hive.openBox(boxName);
    return box.values.map((item) => Map<String, String>.from(item)).toList();
  }

  Future<void> removeItem(int index) async {
    final box = await Hive.openBox(boxName);
    await box.deleteAt(index);
  }
}