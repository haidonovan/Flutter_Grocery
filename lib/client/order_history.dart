import 'package:flutter/material.dart';

import 'models.dart';
import '../widgets/skeleton.dart';

class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({
    super.key,
    required this.orders,
    required this.isLoading,
  });

  final List<OrderRecord> orders;
  final bool isLoading;

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

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.shipped:
        return Colors.blue;
      case OrderStatus.processing:
        return Colors.orange;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      if (isLoading) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonBox(height: 110),
          ),
        );
      }
      return const Center(
        child: Text('No orders yet. Completed orders will show here.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Order ${order.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '\$${order.total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDate(order.createdAt)} - ${_statusText(order.status)}',
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusText(order.status),
                    style: TextStyle(
                      color: _statusColor(order.status),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Payment: ${order.paymentMethod}'),
              ),
              if (order.couponCode != null && order.couponDiscount != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Coupon ${order.couponCode}: -\$${order.couponDiscount!.toStringAsFixed(2)}',
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Address: ${order.shippingAddress}'),
              ),
              if (order.trackingNumber != null ||
                  order.trackingCarrier != null ||
                  order.trackingStatus != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tracking: ${order.trackingCarrier ?? 'Carrier'}',
                      ),
                  if (order.trackingNumber != null)
                        Text('Number: ${order.trackingNumber}'),
                  if (order.trackingStatus != null)
                        Text('Status: ${order.trackingStatus}'),
                      if (order.trackingUpdatedAt != null)
                        Text(
                          'Updated: ${_formatDate(order.trackingUpdatedAt!)}',
                        ),
                    ],
                  ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${line.productName} x${line.quantity}'),
                            if (line.discountPercent > 0)
                              Text(
                                'Discount ${line.discountPercent.toStringAsFixed(0)}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                          ],
                        ),
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
