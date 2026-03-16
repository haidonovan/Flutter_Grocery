import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';
import '../utils/csv_export.dart';
import '../widgets/skeleton.dart';

class OrderManagementPage extends StatefulWidget {
  const OrderManagementPage({super.key, required this.store});

  final GroceryStoreState store;

  @override
  State<OrderManagementPage> createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  String _query = '';
  String _statusFilter = 'All';
  String _sort = 'Newest';
  DateTimeRange? _dateRange;
  final Set<String> _statusUpdatingOrderIds = <String>{};
  final Set<String> _trackingUpdatingOrderIds = <String>{};

  List<DropdownMenuItem<OrderStatus>> _statusItems(BuildContext context) {
    return OrderStatus.values
        .map(
          (status) => DropdownMenuItem<OrderStatus>(
            value: status,
            child: Text(
              status.name[0].toUpperCase() + status.name.substring(1),
              style: TextStyle(
                color: _statusColor(context, status),
                fontWeight: FontWeight.w700,
              ),
            ),
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


  Color _statusColor(BuildContext context, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFC98A09);
      case OrderStatus.processing:
        return const Color(0xFF2563EB);
      case OrderStatus.shipped:
        return const Color(0xFF7C3AED);
      case OrderStatus.delivered:
        return const Color(0xFF1E8E3E);
      case OrderStatus.cancelled:
        return const Color(0xFFC62828);
    }
  }

  Color _statusBackground(BuildContext context, OrderStatus status) {
    return _statusColor(context, status).withValues(alpha: 0.12);
  }

  Color _statusBorder(BuildContext context, OrderStatus status) {
    return _statusColor(context, status).withValues(alpha: 0.28);
  }

  Widget _statusBadge(BuildContext context, OrderStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _statusBackground(context, status),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _statusBorder(context, status)),
      ),
      child: Text(
        status.name[0].toUpperCase() + status.name.substring(1),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: _statusColor(context, status),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
      setState(() {
        _dateRange = picked;
      });
    }
  }

  bool _inDateRange(OrderRecord order) {
    final range = _dateRange;
    if (range == null) {
      return true;
    }
    final created = order.createdAt;
    return !created.isBefore(range.start) &&
        !created.isAfter(range.end.add(const Duration(days: 1)));
  }

  List<OrderRecord> _filteredOrders(List<OrderRecord> orders) {
    final query = _query.trim().toLowerCase();
    final filtered = orders.where((order) {
      if (_statusFilter != 'All' && order.status.name != _statusFilter) {
        return false;
      }
      if (!_inDateRange(order)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }

      final invoiceMatch = order.id.toLowerCase().contains(query);
      final customerMatch = order.customerEmail.toLowerCase().contains(query);
      final trackingMatch =
          (order.trackingNumber ?? '').toLowerCase().contains(query) ||
          (order.trackingCarrier ?? '').toLowerCase().contains(query) ||
          (order.trackingStatus ?? '').toLowerCase().contains(query);
      final productMatch = order.lines.any(
        (line) => line.productName.toLowerCase().contains(query),
      );
      return invoiceMatch || customerMatch || trackingMatch || productMatch;
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

  Future<void> _showTrackingDialog(
    BuildContext context,
    OrderRecord order,
  ) async {
    if (_trackingUpdatingOrderIds.contains(order.id)) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
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
      setState(() {
        _trackingUpdatingOrderIds.add(order.id);
      });
      try {
        await widget.store.updateOrderTracking(
          orderId: order.id,
          trackingCarrier: carrierController.text.trim(),
          trackingNumber: numberController.text.trim(),
          trackingStatus: statusController.text.trim(),
        );
        if (!mounted) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text('Tracking updated for ${order.id}.')),
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      } finally {
        if (mounted) {
          setState(() {
            _trackingUpdatingOrderIds.remove(order.id);
          });
        }
      }
    }
  }

  Future<void> _updateStatus(OrderRecord order, OrderStatus next) async {
    if (_statusUpdatingOrderIds.contains(order.id) || order.status == next) {
      return;
    }

    setState(() {
      _statusUpdatingOrderIds.add(order.id);
    });
    try {
      await widget.store.updateOrderStatus(order.id, next);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order ${order.id} marked ${next.name}.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _statusUpdatingOrderIds.remove(order.id);
        });
      }
    }
  }

  Future<void> _exportOrders(List<OrderRecord> orders) async {
    final rows = <List<String>>[
      [
        'Order ID',
        'Customer',
        'Status',
        'Created At',
        'Total',
        'Tracking Carrier',
        'Tracking Number',
        'Tracking Status',
      ],
      ...orders.map(
        (order) => [
          order.id,
          order.customerEmail,
          order.status.name,
          order.createdAt.toIso8601String(),
          order.total.toStringAsFixed(2),
          order.trackingCarrier ?? '',
          order.trackingNumber ?? '',
          order.trackingStatus ?? '',
        ],
      ),
    ];
    final success = await exportCsv(csvFilename('orders_export'), buildCsv(rows));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Orders CSV downloaded.'
              : 'CSV export is available on web builds.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        if (widget.store.isLoadingOrders && widget.store.allOrders.isEmpty) {
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: 4,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SkeletonBox(height: 120),
            ),
          );
        }

        final filteredOrders = _filteredOrders(widget.store.allOrders);

        if (widget.store.allOrders.isEmpty) {
          return const Center(child: Text('No orders placed yet.'));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: _OrderToolbar(
                query: _query,
                statusFilter: _statusFilter,
                sort: _sort,
                dateRange: _dateRange,
                onQueryChanged: (value) => setState(() => _query = value),
                onStatusChanged: (value) {
                  if (value != null) {
                    setState(() => _statusFilter = value);
                  }
                },
                onSortChanged: (value) {
                  if (value != null) {
                    setState(() => _sort = value);
                  }
                },
                onPickDateRange: _pickDateRange,
                onClearDateRange: () => setState(() => _dateRange = null),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(
                children: [
                  Text(
                    '${filteredOrders.length} order${filteredOrders.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _exportOrders(filteredOrders),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredOrders.isEmpty
                  ? const Center(
                      child: Text('No matching orders for this filter.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        final isStatusUpdating = _statusUpdatingOrderIds.contains(order.id);
                        final isTrackingUpdating = _trackingUpdatingOrderIds.contains(order.id);
                        final statusColor = _statusColor(context, order.status);
                        return Card(
                          child: ExpansionTile(
                            title: Text(order.id),
                            subtitle: Text(
                              '${order.customerEmail} | ${_formatDate(order.createdAt)}',
                            ),
                            trailing: SizedBox(
                              width: 170,
                              child: Stack(
                                alignment: Alignment.centerRight,
                                children: [
                                  IgnorePointer(
                                    ignoring: isStatusUpdating,
                                    child: DropdownButtonFormField<OrderStatus>(
                                      key: ValueKey('${order.id}-${order.status.name}'),
                                      initialValue: order.status,
                                      dropdownColor: Theme.of(context).cardColor,
                                      iconEnabledColor: statusColor,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        filled: true,
                                        fillColor: _statusBackground(context, order.status),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: _statusBorder(context, order.status),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: _statusBorder(context, order.status),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: statusColor,
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                      selectedItemBuilder: (context) => OrderStatus.values
                                          .map(
                                            (status) => Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                status.name[0].toUpperCase() +
                                                    status.name.substring(1),
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: _statusColor(
                                                        context,
                                                        status,
                                                      ),
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          )
                                          .toList(growable: false),
                                      items: _statusItems(context),
                                      onChanged: (next) async {
                                        if (next != null) {
                                          await _updateStatus(order, next);
                                        }
                                      },
                                    ),
                                  ),
                                  if (isStatusUpdating)
                                    Positioned(
                                      right: 12,
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            statusColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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
                                child: Text(
                                  'Address: ${order.shippingAddress}',
                                ),
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
                                  onPressed: isTrackingUpdating
                                      ? null
                                      : () => _showTrackingDialog(context, order),
                                  icon: isTrackingUpdating
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              statusColor,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.local_shipping_outlined,
                                        ),
                                  label: Text(
                                    isTrackingUpdating
                                        ? 'Saving tracking...'
                                        : 'Update tracking',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _statusBadge(context, order.status),
                                  if (isTrackingUpdating)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Tracking sync in progress',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Total: \$${order.total.toStringAsFixed(2)}',
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...order.lines.map(
                                (line) => Row(
                                  children: [
                                    Expanded(
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
                                    Text(
                                      '\$${line.subtotal.toStringAsFixed(2)}',
                                    ),
                                  ],
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
      },
    );
  }
}

class _OrderToolbar extends StatelessWidget {
  const _OrderToolbar({
    required this.query,
    required this.statusFilter,
    required this.sort,
    required this.dateRange,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onPickDateRange,
    required this.onClearDateRange,
  });

  final String query;
  final String statusFilter;
  final String sort;
  final DateTimeRange? dateRange;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final search = TextField(
      decoration: InputDecoration(
        hintText: 'Search invoice, customer, tracking, product',
        prefixIcon: Icon(Icons.search, color: scheme.primary),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                onPressed: () => onQueryChanged(''),
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: onQueryChanged,
    );

    final status = DropdownButtonFormField<String>(
      initialValue: statusFilter,
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
        DropdownMenuItem(value: 'processing', child: Text('Processing')),
        DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
        DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
      ],
      onChanged: onStatusChanged,
    );

    final sortField = DropdownButtonFormField<String>(
      initialValue: sort,
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
      onChanged: onSortChanged,
    );

    final dateText = dateRange == null
        ? 'Any date'
        : '${dateRange!.start.month}/${dateRange!.start.day}/${dateRange!.start.year} - ${dateRange!.end.month}/${dateRange!.end.day}/${dateRange!.end.year}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
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
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPickDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(dateText),
                  ),
                  if (dateRange != null)
                    TextButton(
                      onPressed: onClearDateRange,
                      child: const Text('Clear range'),
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
                  onPressed: onPickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(dateText),
                ),
                if (dateRange != null)
                  TextButton(
                    onPressed: onClearDateRange,
                    child: const Text('Clear range'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
