import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key, required this.store});

  final GroceryStoreState store;

  int get _pendingOrders => store.allOrders
      .where((order) => order.status == OrderStatus.pending)
      .length;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  title: 'Products',
                  value: '${store.allProducts.length}',
                  icon: Icons.shopping_bag,
                ),
                _MetricCard(
                  title: 'Total Stock',
                  value: '${store.totalStockCount}',
                  icon: Icons.inventory_2,
                ),
                _MetricCard(
                  title: 'Low Stock',
                  value: '${store.lowStockCount}',
                  icon: Icons.warning_amber_rounded,
                ),
                _MetricCard(
                  title: 'Pending Orders',
                  value: '$_pendingOrders',
                  icon: Icons.timelapse,
                ),
                _MetricCard(
                  title: 'Revenue',
                  value: '\$${store.revenueTotal.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Latest Orders',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (store.allOrders.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No orders yet.'),
                ),
              )
            else
              ...store.allOrders
                  .take(5)
                  .map(
                    (order) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text(order.id),
                        subtitle: Text(
                          '${order.customerEmail} • ${order.status.name}',
                        ),
                        trailing: Text('\$${order.total.toStringAsFixed(2)}'),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 10),
              Text(title),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}
