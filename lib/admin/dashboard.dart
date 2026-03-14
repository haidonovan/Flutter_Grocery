import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.store});

  final GroceryStoreState store;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  _ChartRange _range = _ChartRange.sevenDays;
  DateTime? _customStart;
  DateTime? _customEnd;

  int get _pendingOrders => widget.store.allOrders
      .where((order) => order.status == OrderStatus.pending)
      .length;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialStart = _customStart ?? now.subtract(const Duration(days: 7));
    final initialEnd = _customEnd ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _range = _ChartRange.custom;
      });
    }
  }

  _RangeConfig _rangeConfig() {
    final now = DateTime.now();
    switch (_range) {
      case _ChartRange.sevenDays:
        return _RangeConfig(
          start: DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 6)),
          end: DateTime(now.year, now.month, now.day),
          bucketDays: 1,
        );
      case _ChartRange.month:
        return _RangeConfig(
          start: DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 29)),
          end: DateTime(now.year, now.month, now.day),
          bucketDays: 1,
        );
      case _ChartRange.year:
        return _RangeConfig(
          start: DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 364)),
          end: DateTime(now.year, now.month, now.day),
          bucketDays: 30,
        );
      case _ChartRange.custom:
        final start = _customStart ??
            DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 6));
        final end = _customEnd ?? DateTime(now.year, now.month, now.day);
        final diffDays = end.difference(start).inDays.abs() + 1;
        final bucketDays = diffDays > 60 ? 7 : 1;
        return _RangeConfig(start: start, end: end, bucketDays: bucketDays);
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final filtered = _filteredOrders(widget.store.allOrders);
        final range = _rangeConfig();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  title: 'Products',
                  value: '${widget.store.allProducts.length}',
                  icon: Icons.shopping_bag,
                ),
                _MetricCard(
                  title: 'Total Stock',
                  value: '${widget.store.totalStockCount}',
                  icon: Icons.inventory_2,
                ),
                _MetricCard(
                  title: 'Low Stock',
                  value: '${widget.store.lowStockCount}',
                  icon: Icons.warning_amber_rounded,
                ),
                _MetricCard(
                  title: 'Pending Orders',
                  value: '$_pendingOrders',
                  icon: Icons.timelapse,
                ),
                _MetricCard(
                  title: 'Revenue',
                  value: '\$${widget.store.revenueTotal.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _RangeSelector(
              selected: _range,
              onSelect: (next) {
                setState(() {
                  _range = next;
                });
                if (next == _ChartRange.custom) {
                  _pickCustomRange();
                }
              },
              onPickCustom: _pickCustomRange,
            ),
            const SizedBox(height: 12),
            _ChartCard(
              title: 'Revenue',
              onExpand: () => _openFullScreen(
                context,
                'Revenue',
                RevenueChart(orders: filtered, range: range),
              ),
              child: SizedBox(
                height: 220,
                child: RevenueChart(orders: filtered, range: range),
              ),
            ),
            const SizedBox(height: 20),
            _ChartCard(
              title: 'Top products',
              onExpand: () => _openFullScreen(
                context,
                'Top products',
                TopProductsChart(orders: filtered),
              ),
              child: SizedBox(
                height: 220,
                child: TopProductsChart(orders: filtered),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Latest Orders',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (widget.store.allOrders.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No orders yet.'),
                ),
              )
            else
              ...widget.store.allOrders
                  .take(5)
                  .map(
                    (order) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text(order.id),
                        subtitle: Text(
                          '${order.customerEmail} - ${order.status.name}',
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

  Future<void> _openFullScreen(
    BuildContext context,
    String title,
    Widget child,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

enum _ChartRange { sevenDays, month, year, custom }

class _RangeConfig {
  const _RangeConfig({
    required this.start,
    required this.end,
    required this.bucketDays,
  });

  final DateTime start;
  final DateTime end;
  final int bucketDays;
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.onSelect,
    required this.onPickCustom,
  });

  final _ChartRange selected;
  final ValueChanged<_ChartRange> onSelect;
  final VoidCallback onPickCustom;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('7 days'),
          selected: selected == _ChartRange.sevenDays,
          onSelected: (_) => onSelect(_ChartRange.sevenDays),
        ),
        ChoiceChip(
          label: const Text('1 month'),
          selected: selected == _ChartRange.month,
          onSelected: (_) => onSelect(_ChartRange.month),
        ),
        ChoiceChip(
          label: const Text('1 year'),
          selected: selected == _ChartRange.year,
          onSelected: (_) => onSelect(_ChartRange.year),
        ),
        ChoiceChip(
          label: const Text('Custom'),
          selected: selected == _ChartRange.custom,
          onSelected: (_) => onPickCustom(),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
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

class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key, required this.orders, required this.range});

  final List<OrderRecord> orders;
  final _RangeConfig range;

  @override
  Widget build(BuildContext context) {
    final data = _bucketedTotals(orders, range);
    final maxValue = data.isEmpty
        ? 1.0
        : data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return CustomPaint(
      painter: _LineChartPainter(
        points: data.map((e) => e.value).toList(),
        maxValue: maxValue == 0 ? 1 : maxValue,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: _AxisLabels(
        dates: data.map((e) => e.label).toList(),
        maxValue: maxValue == 0 ? 1 : maxValue,
      ),
    );
  }

  List<_ChartPoint> _bucketedTotals(
    List<OrderRecord> orders,
    _RangeConfig range,
  ) {
    final totalDays = range.end.difference(range.start).inDays.abs() + 1;
    final bucketDays = range.bucketDays.clamp(1, totalDays);
    final buckets = (totalDays / bucketDays).ceil();
    final totals = List<double>.filled(buckets, 0);

    for (final order in orders) {
      final index = order.createdAt.difference(range.start).inDays ~/ bucketDays;
      if (index >= 0 && index < buckets) {
        totals[index] += order.total;
      }
    }

    return List.generate(buckets, (index) {
      final labelDate = range.start.add(Duration(days: index * bucketDays));
      final label = '${labelDate.month}/${labelDate.day}';
      return _ChartPoint(label: label, value: totals[index]);
    });
  }
}

class TopProductsChart extends StatelessWidget {
  const TopProductsChart({super.key, required this.orders});

  final List<OrderRecord> orders;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final order in orders) {
      if (order.status == OrderStatus.cancelled) {
        continue;
      }
      for (final line in order.lines) {
        counts[line.productName] =
            (counts[line.productName] ?? 0) + line.quantity;
      }
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = top.take(5).toList();
    if (topItems.isEmpty) {
      return const Center(child: Text('No sales data yet.'));
    }

    final maxValue = topItems.first.value.toDouble();
    return ListView.separated(
      itemCount: topItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = topItems[index];
        final widthFactor = item.value / maxValue;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.key, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Stack(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: widthFactor,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text('${item.value} sold', style: Theme.of(context).textTheme.bodySmall),
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

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.dates, required this.maxValue});

  final List<String> dates;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final steps = 4;
    return Padding(
      padding: const EdgeInsets.only(left: 36, right: 8, bottom: 12, top: 8),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              steps + 1,
              (index) {
                final value = maxValue * (1 - index / steps);
                return Text(
                  '\$${value.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: dates
                  .map(
                    (label) => Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.points,
    required this.maxValue,
    required this.color,
  });

  final List<double> points;
  final double maxValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final chartPadding = const EdgeInsets.fromLTRB(36, 12, 8, 24);
    final rect = Rect.fromLTWH(
      chartPadding.left,
      chartPadding.top,
      size.width - chartPadding.left - chartPadding.right,
      size.height - chartPadding.top - chartPadding.bottom,
    );
    final safeMax = maxValue <= 0 ? 1 : maxValue;

    final axisPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.right, rect.bottom),
      axisPaint,
    );

    if (points.isEmpty) {
      return;
    }

    final path = Path();
    if (points.length == 1) {
      final x = rect.left;
      final y = rect.bottom - (points.first / safeMax) * rect.height;
      path.moveTo(x, y);
    } else {
      for (var i = 0; i < points.length; i += 1) {
        final x = rect.left + (rect.width / (points.length - 1)) * i;
        final y = rect.bottom - (points[i] / safeMax) * rect.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = color;
    if (points.length == 1) {
      final x = rect.left;
      final y = rect.bottom - (points.first / safeMax) * rect.height;
      canvas.drawCircle(Offset(x, y), 3.5, pointPaint);
    } else {
      for (var i = 0; i < points.length; i += 1) {
        final x = rect.left + (rect.width / (points.length - 1)) * i;
        final y = rect.bottom - (points[i] / safeMax) * rect.height;
        canvas.drawCircle(Offset(x, y), 3.5, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChartPoint {
  const _ChartPoint({required this.label, required this.value});

  final String label;
  final double value;
}
