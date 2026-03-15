import 'package:flutter/material.dart';

import '../widgets/skeleton.dart';
import 'models.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({
    super.key,
    required this.orders,
    required this.isLoading,
  });

  final List<OrderRecord> orders;
  final bool isLoading;

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  String _query = '';
  String _status = 'All';
  String _sort = 'Newest';
  DateTimeRange? _dateRange;

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

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  List<OrderRecord> _filteredOrders() {
    final query = _query.trim().toLowerCase();
    final filtered = widget.orders.where((order) {
      if (_status != 'All' && order.status.name != _status) {
        return false;
      }
      if (_dateRange != null &&
          (order.createdAt.isBefore(_dateRange!.start) ||
              order.createdAt.isAfter(
                _dateRange!.end.add(const Duration(days: 1)),
              ))) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return order.id.toLowerCase().contains(query) ||
          order.paymentMethod.toLowerCase().contains(query) ||
          order.shippingAddress.toLowerCase().contains(query) ||
          order.lines.any(
            (line) => line.productName.toLowerCase().contains(query),
          );
    }).toList();

    switch (_sort) {
      case 'Oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'Total high-low':
        filtered.sort((a, b) => b.total.compareTo(a.total));
        break;
      case 'Total low-high':
        filtered.sort((a, b) => a.total.compareTo(b.total));
        break;
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) {
      if (widget.isLoading) {
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

    final orders = _filteredOrders();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final search = TextField(
                decoration: InputDecoration(
                  hintText: 'Search order ID, address, payment, product',
                  prefixIcon: Icon(Icons.search, color: scheme.primary),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() => _query = ''),
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              );

              final status = DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All status')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(
                    value: 'processing',
                    child: Text('Processing'),
                  ),
                  DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                  DropdownMenuItem(
                    value: 'delivered',
                    child: Text('Delivered'),
                  ),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              );

              final sortField = DropdownButtonFormField<String>(
                initialValue: _sort,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Newest', child: Text('Newest')),
                  DropdownMenuItem(value: 'Oldest', child: Text('Oldest')),
                  DropdownMenuItem(
                    value: 'Total high-low',
                    child: Text('Total high-low'),
                  ),
                  DropdownMenuItem(
                    value: 'Total low-high',
                    child: Text('Total low-high'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _sort = value);
                  }
                },
              );

              final dateText = _dateRange == null
                  ? 'Date range'
                  : '${_dateRange!.start.month}/${_dateRange!.start.day} - ${_dateRange!.end.month}/${_dateRange!.end.day}';

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: 10),
                    status,
                    const SizedBox(height: 10),
                    sortField,
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickDateRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(dateText),
                        ),
                        if (_dateRange != null)
                          TextButton(
                            onPressed: () => setState(() => _dateRange = null),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: status),
                      const SizedBox(width: 10),
                      Expanded(child: sortField),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(dateText),
                      ),
                      if (_dateRange != null)
                        TextButton(
                          onPressed: () => setState(() => _dateRange = null),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? const Center(child: Text('No orders for this filter.'))
              : ListView.builder(
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(
                                  order.status,
                                ).withValues(alpha: 0.15),
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
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Payment: ${order.paymentMethod}'),
                          ),
                          if (order.couponCode != null &&
                              order.couponDiscount != null)
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
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  SizedBox(
                                    width: 220,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${line.productName} x${line.quantity}',
                                        ),
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
                ),
        ),
      ],
    );
  }
}
