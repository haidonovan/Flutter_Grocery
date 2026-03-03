import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';

class SalesReportPage extends StatelessWidget {
  const SalesReportPage({super.key, required this.store});

  final GroceryStoreState store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final deliveredCount = store.allOrders
            .where((order) => order.status == OrderStatus.delivered)
            .length;
        final cancelledCount = store.allOrders
            .where((order) => order.status == OrderStatus.cancelled)
            .length;

        final productSales = <String, int>{};
        for (final order in store.allOrders) {
          if (order.status == OrderStatus.cancelled) {
            continue;
          }
          for (final line in order.lines) {
            productSales[line.productName] =
                (productSales[line.productName] ?? 0) + line.quantity;
          }
        }

        final topProducts = productSales.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${store.revenueTotal.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cancelled order value: \$${store.cancelledValue.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Total orders: ${store.allOrders.length}'),
                    ),
                    Expanded(child: Text('Delivered: $deliveredCount')),
                    Expanded(child: Text('Cancelled: $cancelledCount')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Top selling products',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (topProducts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No sales data yet.'),
                ),
              )
            else
              ...topProducts
                  .take(10)
                  .map(
                    (entry) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.trending_up),
                        title: Text(entry.key),
                        trailing: Text('${entry.value} sold'),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}
