import 'package:flutter/material.dart';
import 'local_storage.dart';

class ShoppingListProvider with ChangeNotifier {
  final List<Map<String, String>> _items = [];
  final LocalStorageService _localStorage = LocalStorageService();

  List<Map<String, String>> get items => _items;

  ShoppingListProvider() {
    _loadItems();
  }

  Future<void> _loadItems() async {
    final storedItems = await _localStorage.getItems();
    _items.addAll(storedItems);
    notifyListeners();
  }

  Future<void> addItem(String name, String quantity) async {
    _items.add({'name': name, 'quantity': quantity});
    await _localStorage.addItem(name, quantity);
    notifyListeners();
  }

  Future<void> removeItem(int index) async {
    _items.removeAt(index);
    await _localStorage.removeItem(index);
    notifyListeners();
  }
}