import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';
import '../widgets/skeleton.dart';

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

  Future<void> _showTrackingDialog(
    BuildContext context,
    OrderRecord order,
  ) async {
    final numberController = TextEditingController(
      text: order.trackingNumber ?? '',
    );
    final carrierController = TextEditingController(
      text: order.trackingCarrier ?? '',
    );
    final statusController = TextEditingController(
      text: order.trackingStatus ?? '',
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update tracking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: carrierController,
              decoration: const InputDecoration(labelText: 'Carrier'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: numberController,
              decoration: const InputDecoration(labelText: 'Tracking number'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: statusController,
              decoration: const InputDecoration(labelText: 'Tracking status'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      await store.updateOrderTracking(
        orderId: order.id,
        trackingCarrier: carrierController.text.trim(),
        trackingNumber: numberController.text.trim(),
        trackingStatus: statusController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.isLoadingOrders) {
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: 4,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SkeletonBox(height: 120),
            ),
          );
        }
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
                subtitle: Text(
                  '${order.customerEmail} • ${_formatDate(order.createdAt)}',
                ),
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
                  if (order.couponCode != null &&
                      order.couponDiscount != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Coupon ${order.couponCode}: -\$${order.couponDiscount!.toStringAsFixed(2)}',
                      ),
                    ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tracking: ${order.trackingCarrier ?? '-'}',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Number: ${order.trackingNumber ?? '-'}',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Status: ${order.trackingStatus ?? '-'}',
                    ),
                  ),
                  if (order.trackingUpdatedAt != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Updated: ${_formatDate(order.trackingUpdatedAt!)}',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _showTrackingDialog(context, order),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Update tracking'),
                    ),
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
                ],
              ),
            );
          },
        );
      },
    );
  }
}
