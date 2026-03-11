import 'package:flutter/material.dart';

import 'models.dart';

class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({super.key, required this.orders});

  final List<OrderRecord> orders;

  String _formatDate(DateTime value) {
    final months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[value.month - 1];
    return '${value.day} $month ${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _statusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Text('No orders yet. Completed orders will show here.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,

      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            title: Text('Order ${order.id}'),
            subtitle: Text(
              '${_formatDate(order.createdAt)} • ${_statusText(order.status)}',
            ),
            trailing: Text('\$${order.total.toStringAsFixed(2)}'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Payment: ${order.paymentMethod}'),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Address: ${order.shippingAddress}'),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...order.lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${line.productName} x${line.quantity}'),
                      ),
                      Text('\$${line.subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
