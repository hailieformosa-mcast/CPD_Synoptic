import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'notifications.dart';
import 'firebase_setup.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.instance.initialize();
  await notificationService.initialize();
  await Hive.initFlutter();
  final box = await Hive.openBox('shoppingBox');

  runApp(
    ChangeNotifierProvider(
      create: (context) => ShoppingListProvider(box),
      child: const ShoppingListApp(),
    ),
  );
}

 

class ShoppingListProvider with ChangeNotifier {
  final Box _box;

  final List<Map<String, String>> _toGetItems = [];
  final List<Map<String, String>> _inCartItems = [];

  ShoppingListProvider(this._box) {
    // Load persisted lists from Hive
    final storedToGet = _box.get('toGet');
    final storedInCart = _box.get('inCart');
    if (storedToGet is List) {
      for (final e in storedToGet) {
        if (e is Map) {
          _toGetItems.add(Map<String, String>.from(e.cast<String, dynamic>()));
        }
      }
    }
    if (storedInCart is List) {
      for (final e in storedInCart) {
        if (e is Map) {
          _inCartItems.add(Map<String, String>.from(e.cast<String, dynamic>()));
        }
      }
    }
  }

  List<Map<String, String>> get toGetItems => _toGetItems;
  List<Map<String, String>> get inCartItems => _inCartItems;

  void _persist() {
    _box.put('toGet', _toGetItems);
    _box.put('inCart', _inCartItems);
  }

  void addItem(String name, String quantity) {
    _toGetItems.add({'name': name, 'quantity': quantity});
    _persist();
    try {
      FirebaseService.instance.logAddItem(name);
    } catch (_) {}
    notifyListeners();
  }

  void editItem(int index, String name, String quantity, bool inCart) {
    final list = inCart ? _inCartItems : _toGetItems;
    if (index >= 0 && index < list.length) {
      list[index] = {'name': name, 'quantity': quantity};
      _persist();
      notifyListeners();
    }
  }

  void markAsInCart(int index) {
    final item = _toGetItems.removeAt(index);
    _inCartItems.add(item);
    _persist();
    // trigger a local notification to inform the user
    try {
      notificationService.showNotification('Added to cart', '${item['name']} added to cart');
    } catch (_) {}
    try {
      FirebaseService.instance.logMoveToCart(item['name'] ?? '', item['quantity'] ?? '');
    } catch (_) {}
    notifyListeners();
  }

  void moveBackToToGet(int index) {
    final item = _inCartItems.removeAt(index);
    _toGetItems.add(item);
    _persist();
    notifyListeners();
  }

  void removeItem(int index, bool inCart) {
    final list = inCart ? _inCartItems : _toGetItems;
    list.removeAt(index);
    _persist();
    notifyListeners();
  }
}

class ShoppingListApp extends StatelessWidget {
  const ShoppingListApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shopping List App',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: Colors.grey[50],
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: const ShoppingListScreen(),
    );
  }
}

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final shoppingListProvider = Provider.of<ShoppingListProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        backgroundColor: Colors.blueGrey,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: PopupMenuButton<String>(
            tooltip: 'Menu',
            offset: const Offset(0, 56),
            color: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            icon: Container(
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.menu, color: Colors.white),
            ),
            onSelected: (value) {
              if (value == 'Add Item') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddItemScreen()),
                );
              } else if (value == 'About') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Add Item',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add, color: Colors.blueGrey),
                  title: const Text('Add Item',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'About',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                  title: const Text('About',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.store),
            tooltip: 'Find Nearby Grocery Stores',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'To Get',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: shoppingListProvider.toGetItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No items to get. Add items to get started!',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: shoppingListProvider.toGetItems.length,
                          itemBuilder: (context, index) {
                            final item = shoppingListProvider.toGetItems[index];
                            return ShoppingListItem(
                              item: item,
                              onEdit: (name, quantity) {
                                shoppingListProvider.editItem(index, name, quantity, false);
                              },
                              onToggleInCart: () {
                                shoppingListProvider.markAsInCart(index);
                              },
                              onEditTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddItemScreen(
                                      initialName: item['name'],
                                      initialQuantity: item['quantity'],
                                      editIndex: index,
                                      editInCart: false,
                                    ),
                                  ),
                                );
                              },
                              onDelete: () {
                                shoppingListProvider.removeItem(index, false);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.grey),
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'In Cart',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: shoppingListProvider.inCartItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No items in cart.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: shoppingListProvider.inCartItems.length,
                          itemBuilder: (context, index) {
                            final item = shoppingListProvider.inCartItems[index];
                            return ShoppingListItem(
                              item: item,
                              onEdit: (name, quantity) {
                                shoppingListProvider.editItem(index, name, quantity, true);
                              },
                              onToggleInCart: () {
                                shoppingListProvider.moveBackToToGet(index);
                              },
                              onEditTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddItemScreen(
                                      initialName: item['name'],
                                      initialQuantity: item['quantity'],
                                      editIndex: index,
                                      editInCart: true,
                                    ),
                                  ),
                                );
                              },
                              onDelete: () {
                                shoppingListProvider.removeItem(index, true);
                              },
                              isInCart: true,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddItemScreen()),
          );
        },
        backgroundColor: Colors.blueGrey,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ShoppingListItem extends StatelessWidget {
  final Map<String, String> item;
  final void Function(String name, String quantity) onEdit;
  final VoidCallback? onToggleInCart;
  final VoidCallback? onEditTap;
  final VoidCallback onDelete;
  final bool isInCart;

  const ShoppingListItem({
    Key? key,
    required this.item,
    required this.onEdit,
    this.onToggleInCart,
    this.onEditTap,
    required this.onDelete,
    this.isInCart = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController(text: item['name']);
    final quantityController = TextEditingController(text: item['quantity']);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            isInCart ? Icons.check_box : Icons.check_box_outline_blank,
            color: Colors.green,
          ),
          onPressed: onToggleInCart,
        ),
        title: TextField(
          controller: nameController,
          decoration: const InputDecoration(border: InputBorder.none),
          onSubmitted: (value) {
            onEdit(nameController.text, quantityController.text);
          },
          onEditingComplete: () {
            onEdit(nameController.text, quantityController.text);
            FocusScope.of(context).unfocus();
          },
        ),
        subtitle: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly, // Ensures only digits are allowed
          ],
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Enter quantity (numbers only)',
          ),
          onChanged: (value) {
            // Prevent invalid input from being processed
            if (value.isNotEmpty && int.tryParse(value) == null) {
              quantityController.text = value.replaceAll(RegExp(r'[^0-9]'), '');
              quantityController.selection = TextSelection.fromPosition(
                TextPosition(offset: quantityController.text.length),
              );
            }
          },
          onSubmitted: (value) {
            onEdit(nameController.text, quantityController.text);
          },
          onEditingComplete: () {
            onEdit(nameController.text, quantityController.text);
            FocusScope.of(context).unfocus();
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueGrey),
              onPressed: onEditTap,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class AddItemScreen extends StatelessWidget {
  final String? initialName;
  final String? initialQuantity;
  final int? editIndex;
  final bool editInCart;

  const AddItemScreen({
    Key? key,
    this.initialName,
    this.initialQuantity,
    this.editIndex,
    this.editInCart = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final shoppingListProvider = Provider.of<ShoppingListProvider>(context, listen: false);
    final nameController = TextEditingController(text: initialName ?? '');
    final quantityController = TextEditingController(text: initialQuantity ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a new item to your shopping list:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.blueGrey,
                ),
                onPressed: () {
                  if (editIndex != null) {
                    shoppingListProvider.editItem(editIndex!, nameController.text, quantityController.text, editInCart);
                  } else {
                    shoppingListProvider.addItem(
                      nameController.text,
                      quantityController.text,
                    );
                  }
                  Navigator.pop(context);
                },
                child: const Text('Add Item', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.blueGrey,
        elevation: 2,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.blueGrey,
                      child: const Icon(Icons.shopping_cart, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Shopping List',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage your items, find nearby stores, and stay organized.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text('Close'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLatLng;
  List<Map<String, dynamic>> _stores = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled.';
          _loading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Location permissions are denied.';
            _loading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permissions are permanently denied.';
          _loading = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentLatLng = latlng;
        _loading = false;
      });

      // fetch nearby stores
      _fetchNearbyStores(latlng.latitude, latlng.longitude);

      // Move the map to the user's location after a short delay so the map can initialize.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(latlng, 14.0);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get location.';
        _loading = false;
      });
    }
  }

  Future<void> _fetchNearbyStores(double lat, double lon) async {
    try {
      final radius = 1500; // meters
      final query = '''
        [out:json][timeout:25];
        (
          node["shop"~"supermarket|convenience"](around:$radius,$lat,$lon);
          way["shop"~"supermarket|convenience"](around:$radius,$lat,$lon);
          relation["shop"~"supermarket|convenience"](around:$radius,$lat,$lon);
        );
        out center;
      ''';

      final uri = Uri.parse('https://overpass-api.de/api/interpreter');
      final resp = await http.post(uri, body: {'data': query});
      if (resp.statusCode != 200) {
        return;
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>;
      final stores = <Map<String, dynamic>>[];
      for (final el in elements) {
        final e = el as Map<String, dynamic>;
        double? latEl;
        double? lonEl;
        if (e['type'] == 'node') {
          latEl = (e['lat'] as num).toDouble();
          lonEl = (e['lon'] as num).toDouble();
        } else if (e.containsKey('center')) {
          final center = e['center'] as Map<String, dynamic>;
          latEl = (center['lat'] as num).toDouble();
          lonEl = (center['lon'] as num).toDouble();
        }
        if (latEl != null && lonEl != null) {
          stores.add({
            'name': (e['tags'] != null && e['tags']['name'] != null) ? e['tags']['name'] : 'Store',
            'lat': latEl,
            'lon': lonEl,
            'tags': e['tags'] ?? {},
          });
        }
      }
      setState(() {
        _stores = stores;
      });
    } catch (_) {
      // ignore fetch errors silently for now
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Grocery Stores'),
        backgroundColor: Colors.blueGrey,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _currentLatLng ?? LatLng(0, 0),
                    zoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLatLng!,
                          width: 50,
                          height: 50,
                          builder: (ctx) => const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 36,
                          ),
                        ),
                        ..._stores.map((s) => Marker(
                              point: LatLng(s['lat'] as double, s['lon'] as double),
                              width: 40,
                              height: 40,
                              builder: (ctx) => GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (_) => Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Text((s['tags'] as Map)['shop'] ?? ''),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: const Icon(Icons.store, color: Colors.redAccent, size: 30),
                              ),
                            ))
                            .toList(),
                      ],
                    ),
                  ],
                ),
    );
  }
}
