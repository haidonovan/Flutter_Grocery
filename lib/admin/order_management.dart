import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';

class OrderManagementPage extends StatelessWidget {
  const OrderManagementPage({super.key, required this.store});

  final GroceryStoreState store;

  List<DropdownMenuItem<OrderStatus>> get _statusItems {
    return OrderStatus.values
        .map(
          (status) => DropdownMenuItem<OrderStatus>(
            value: status,
            child: Text(status.name),
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.allOrders.isEmpty) {
          return const Center(child: Text('No orders placed yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: store.allOrders.length,
          itemBuilder: (context, index) {
            final order = store.allOrders[index];
            return Card(
              child: ExpansionTile(
                title: Text(order.id),
                subtitle: Text(order.customerEmail),
                trailing: SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<OrderStatus>(
                    initialValue: order.status,
                    items: _statusItems,
                    onChanged: (next) {
                      if (next != null) {
                        store.updateOrderStatus(order.id, next);
                      }
                    },
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Address: ${order.shippingAddress}'),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Payment: ${order.paymentMethod}'),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Total: \$${order.total.toStringAsFixed(2)}'),
                  ),
                  const SizedBox(height: 10),
                  ...order.lines.map(
                    (line) => Row(
                      children: [
                        Expanded(
                          child: Text('${line.productName} x${line.quantity}'),
                        ),
                        Text('\$${line.subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
