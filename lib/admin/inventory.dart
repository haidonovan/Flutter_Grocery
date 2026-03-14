import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key, required this.store});

  final GroceryStoreState store;

  Future<void> _restock(BuildContext context, Product product) async {
    final controller = TextEditingController();

    final value = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Restock ${product.name}'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity to add',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final qty = int.tryParse(controller.text.trim());
                Navigator.of(context).pop(qty);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (value != null && value > 0) {
      store.restockProduct(product.id, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ...store.allProducts.map(
              (product) => Card(
                child: ListTile(
                  title: Text(product.name),
                  subtitle: Text('Category: ${product.category}'),
                  trailing: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Stock ${product.stock}',
                          style: TextStyle(
                            color:
                                product.stock <= 5 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.tonal(
                          onPressed: () => _restock(context, product),
                          child: const Text('Restock'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Recent restocks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (store.restockHistory.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No restock records yet.'),
                ),
              )
            else
              ...store.restockHistory
                  .take(8)
                  .map(
                    (entry) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.add_box_outlined),
                        title: Text(entry.productName),
                        subtitle: Text(entry.createdAt.toLocal().toString()),
                        trailing: Text('+${entry.quantityAdded}'),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}
