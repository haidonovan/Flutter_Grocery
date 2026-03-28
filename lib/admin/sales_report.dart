import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';
import 'dashboard.dart';
import '../utils/csv_export.dart';
import '../widgets/entrance_motion.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key, required this.store});

  final GroceryStoreState store;

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  ChartRange _range = ChartRange.month;
  DateTime? _customStart;
  DateTime? _customEnd;
  String _query = '';

  Future<void> _openFullScreen(
    BuildContext context,
    String title,
    Widget child,
  ) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) =>
          Dialog.fullscreen(
            child: EntranceMotion(
              duration: const Duration(milliseconds: 520),
              beginOffset: const Offset(0.06, 0),
              child: Scaffold(
                appBar: AppBar(title: Text(title)),
                body: Padding(padding: const EdgeInsets.all(16), child: child),
              ),
            ),
          ),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: _customStart ?? now.subtract(const Duration(days: 29)),
        end: _customEnd ?? now,
      ),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _range = ChartRange.custom;
      });
    }
  }

  RevenueRangeConfig _rangeConfig() {
    final now = DateTime.now();
    switch (_range) {
      case ChartRange.sevenDays:
        return RevenueRangeConfig(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
          end: DateTime(now.year, now.month, now.day),
          bucketDays: 1,
        );
      case ChartRange.month:
        return RevenueRangeConfig(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 29)),
          end: DateTime(now.year, now.month, now.day),
          bucketDays: 1,
        );
      case ChartRange.year:
        return RevenueRangeConfig(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 364)),
          end: DateTime(now.year, now.month, now.day),
          bucketDays: 30,
        );
      case ChartRange.custom:
        final start =
            _customStart ??
            DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 29));
        final end = _customEnd ?? DateTime(now.year, now.month, now.day);
        final diffDays = end.difference(start).inDays.abs() + 1;
        return RevenueRangeConfig(
          start: start,
          end: end,
          bucketDays: diffDays > 60 ? 7 : 1,
        );
    }
  }

  List<OrderRecord> _filteredOrders(List<OrderRecord> orders) {
    final range = _rangeConfig();
    return orders.where((order) {
      if (order.status == OrderStatus.cancelled) {
        return false;
      }
      return !order.createdAt.isBefore(range.start) &&
          !order.createdAt.isAfter(range.end.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> _exportSales(
    List<MapEntry<String, int>> topProducts,
    List<OrderRecord> orders,
  ) async {
    final rows = <List<String>>[
      ['Section', 'Name', 'Value', 'Date'],
      ...orders.map(
        (order) => [
          'Revenue',
          order.id,
          order.total.toStringAsFixed(2),
          order.createdAt.toIso8601String(),
        ],
      ),
      ...topProducts.map(
        (entry) => ['Top Product', entry.key, entry.value.toString(), ''],
      ),
    ];
    final success = await exportCsv(
      csvFilename('sales_export'),
      buildCsv(rows),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? csvExportSuccessMessage('Sales')
                : csvExportFailureMessage(),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final filteredOrders = _filteredOrders(widget.store.allOrders);
        final range = _rangeConfig();
        final deliveredCount = widget.store.allOrders
            .where((order) => order.status == OrderStatus.delivered)
            .length;
        final cancelledCount = widget.store.allOrders
            .where((order) => order.status == OrderStatus.cancelled)
            .length;

        final productSales = <String, int>{};
        for (final order in widget.store.allOrders) {
          if (order.status == OrderStatus.cancelled) {
            continue;
          }
          for (final line in order.lines) {
            productSales[line.productName] =
                (productSales[line.productName] ?? 0) + line.quantity;
          }
        }

        final topProducts =
            productSales.entries
                .where(
                  (entry) => entry.key.toLowerCase().contains(
                    _query.trim().toLowerCase(),
                  ),
                )
                .toList()
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
                      '\$${widget.store.revenueTotal.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cancelled order value: \$${widget.store.cancelledValue.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            RangeSelector(
              selected: _range,
              onSelect: (next) {
                setState(() {
                  _range = next;
                });
                if (next == ChartRange.custom) {
                  _pickCustomRange();
                }
              },
              onPickCustom: _pickCustomRange,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${filteredOrders.length} order${filteredOrders.length == 1 ? '' : 's'} in range',
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _exportSales(topProducts, filteredOrders),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SalesChartCard(
              title: 'Revenue over time',
              onExpand: () => _openFullScreen(
                context,
                'Revenue over time',
                RevenueChart(orders: filteredOrders, range: range),
              ),
              child: SizedBox(
                height: 260,
                child: RevenueChart(orders: filteredOrders, range: range),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text('Total orders: ${widget.store.allOrders.length}'),
                    Text('Delivered: $deliveredCount'),
                    Text('Cancelled: $cancelledCount'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search top-selling product',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() => _query = ''),
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
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

class _SalesChartCard extends StatelessWidget {
  const _SalesChartCard({
    required this.title,
    required this.child,
    required this.onExpand,
  });

  final String title;
  final Widget child;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  onPressed: onExpand,
                  icon: const Icon(Icons.open_in_full),
                  tooltip: 'Open fullscreen',
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}


