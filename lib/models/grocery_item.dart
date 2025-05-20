import 'package:shopping_list/models/category.dart';

class GroceryItem {
  final String id;
  final String name;
  final int quantity;
  final Category category;

  const GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.category,
  });

  @override
  String toString() {
    return 'GroceryItem(id: $id, name: $name, quantity: $quantity, category: $category)';
  }
}
