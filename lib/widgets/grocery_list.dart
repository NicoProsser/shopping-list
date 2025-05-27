import 'package:flutter/material.dart';
import 'package:shopping_list/models/grocery_item.dart';
import 'package:shopping_list/widgets/new_item.dart';
import 'package:shopping_list/data/categories.dart';
import 'package:shopping_list/models/category.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

class GroceryList extends StatefulWidget {
  const GroceryList({super.key});

  /// Creates the mutable state for the GroceryList widget.
  /// Returns an instance of [_GroceryListState].
  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {
  List<GroceryItem> _groceryItems = [];
  var _isLoading = true;
  String? _error;

  /// Called once when the state is initialized.
  /// Starts loading grocery items from the backend.
  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  /// Loads the grocery items from the Firebase Realtime Database.
  ///
  /// - Sends a GET request to the backend.
  /// - Handles error states and empty responses.
  /// - Maps the response data into a list of [GroceryItem]s.
  /// - Updates the UI state accordingly.
  void _loadItems() async {
    final url = Uri.https(
      'shoppinglist-916c4-default-rtdb.firebaseio.com',
      'shopping-list.json',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode >= 400) {
        setState(() {
          _error = 'Failed to load items. Please try again later.';
        });
      }

      if (response.body == 'null') {
        setState(() {
          _groceryItems = [];
          _isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> listData = json.decode(response.body);
      final List<GroceryItem> loadedItems = [];

      for (final item in listData.entries) {
        final category = categories.entries
            .firstWhere(
              (catItem) => catItem.value.title == item.value['category'],
            )
            .value;

        loadedItems.add(
          GroceryItem(
            id: item.key!,
            name: item.value['name'],
            quantity: item.value['quantity'],
            category: category,
          ),
        );
      }

      setState(() {
        _groceryItems = loadedItems;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = 'Something went wrong. Please try again later.';
      });
    }
  }

  /// Opens the [NewItem] screen and waits for a new [GroceryItem] to be added.
  ///
  /// If a new item is returned, it is added to the current grocery list.
  void _addItem() async {
    final newItem = await Navigator.of(
      context,
    ).push<GroceryItem>(MaterialPageRoute(builder: (ctx) => const NewItem()));

    if (newItem == null) {
      return;
    }

    setState(() {
      _groceryItems.add(newItem);
    });

    // Optionally: _loadItems();
  }

  /// Removes a [GroceryItem] from the list and deletes it from Firebase.
  ///
  /// If the deletion fails, the item is reinserted into the list.
  void _removeItem(GroceryItem item) async {
    final index = _groceryItems.indexOf(item);

    setState(() {
      _groceryItems.remove(item);
    });

    final url = Uri.https(
      'shoppinglist-916c4-default-rtdb.firebaseio.com',
      'shopping-list/${item.id}.json',
    );

    final response = await http.delete(url);

    if (response.statusCode >= 400) {
      setState(() {
        _groceryItems.insert(index, item);
      });
    }
  }

  /// Opens a dialog to edit an existing [GroceryItem].
  ///
  /// - Displays a modal form pre-filled with the item's current name, quantity, and category.
  /// - Validates the input and allows the user to save changes or cancel.
  /// - If the user confirms:
  ///   - Updates the item in the local list.
  ///   - Sends a PATCH request to Firebase to update the item remotely.
  ///
  /// This function ensures UI and backend consistency for edited items.
  void _editItem(GroceryItem item) async {
    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(
      text: item.quantity.toString(),
    );
    Category selectedCategory = item.category;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<Category>(
              value: selectedCategory,
              items: categories.entries
                  .map(
                    (cat) => DropdownMenuItem<Category>(
                      value: cat.value,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            color: cat.value.color,
                          ),
                          const SizedBox(width: 8),
                          Text(cat.value.title),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedCategory = value;
                }
              },
              decoration: const InputDecoration(labelText: 'Category'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              final newQuantity =
                  int.tryParse(quantityController.text.trim()) ?? item.quantity;
              if (newName.isNotEmpty && newQuantity > 0) {
                Navigator.of(ctx).pop({
                  'name': newName,
                  'quantity': newQuantity,
                  'category': selectedCategory,
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedItem = GroceryItem(
        id: item.id,
        name: result['name'],
        quantity: result['quantity'],
        category: result['category'],
      );

      final index = _groceryItems.indexWhere((i) => i.id == item.id);
      setState(() {
        _groceryItems[index] = updatedItem;
      });

      // Update in Firebase
      final url = Uri.https(
        'shoppinglist-916c4-default-rtdb.firebaseio.com',
        'shopping-list/${item.id}.json',
      );
      await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': updatedItem.name,
          'quantity': updatedItem.quantity,
          'category': updatedItem.category.title,
        }),
      );
    }
  }

  /// Builds the user interface of the GroceryList screen.
  ///
  /// Shows a loading spinner, the grocery list, an error message,
  /// or a placeholder depending on the current state.
  @override
  Widget build(BuildContext context) {
    Widget content = const Center(
      child: Text('List is empty. Add some items!'),
    );

    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    }

    if (_groceryItems.isNotEmpty) {
      content = ListView.builder(
        itemCount: _groceryItems.length,
        itemBuilder: (ctx, index) => Dismissible(
          onDismissed: (direction) {
            _removeItem(_groceryItems[index]);
          },
          key: ValueKey(_groceryItems[index].id),
          child: ListTile(
            title: Text(_groceryItems[index].name),
            leading: Container(
              width: 24,
              height: 24,
              color: _groceryItems[index].category.color,
            ),
            trailing: Text(_groceryItems[index].quantity.toString()),
            onTap: () => _editItem(_groceryItems[index]),
          ),
        ),
      );
    }

    if (_error != null) {
      content = Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery List'),
        actions: [IconButton(onPressed: _addItem, icon: const Icon(Icons.add))],
      ),
      body: content,
    );
  }
}
