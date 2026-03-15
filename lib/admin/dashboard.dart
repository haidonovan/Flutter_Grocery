import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';
import '../widgets/entrance_motion.dart';
import '../widgets/hover_lift.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.store,
    this.active = true,
  });

  final GroceryStoreState store;
  final bool active;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  ChartRange _range = ChartRange.sevenDays;
  DateTime? _customStart;
  DateTime? _customEnd;
  int _countAnimationSeed = 0;

  @override
  void didUpdateWidget(covariant AdminDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      setState(() {
        _countAnimationSeed += 1;
      });
    }
  }

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
            ).subtract(const Duration(days: 6));
        final end = _customEnd ?? DateTime(now.year, now.month, now.day);
        final diffDays = end.difference(start).inDays.abs() + 1;
        final bucketDays = diffDays > 60 ? 7 : 1;
        return RevenueRangeConfig(
          start: start,
          end: end,
          bucketDays: bucketDays,
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

  List<_DashboardAlert> _buildAlerts() {
    final lowStock = widget.store.lowStockCount;
    final openComplaints = widget.store.supportTickets
        .where((ticket) => ticket.status != 'closed')
        .length;
    final pendingOrders = _pendingOrders;
    final alerts = <_DashboardAlert>[];

    if (openComplaints > 0) {
      alerts.add(
        _DashboardAlert(
          title: 'Customer complaints',
          message:
              '$openComplaints active support ticket${openComplaints == 1 ? '' : 's'} need admin follow-up.',
          icon: Icons.report_problem_outlined,
          tone: _MetricTone.danger,
        ),
      );
    }
    if (lowStock > 0) {
      alerts.add(
        _DashboardAlert(
          title: 'Low stock',
          message:
              '$lowStock product${lowStock == 1 ? '' : 's'} are close to running out.',
          icon: Icons.inventory_2_outlined,
          tone: lowStock >= 5 ? _MetricTone.danger : _MetricTone.warning,
        ),
      );
    }
    if (pendingOrders >= 8) {
      alerts.add(
        _DashboardAlert(
          title: 'Pending orders',
          message:
              '$pendingOrders orders are still pending and should be reviewed.',
          icon: Icons.timelapse_outlined,
          tone: _MetricTone.warning,
        ),
      );
    }

    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final filtered = _filteredOrders(widget.store.allOrders);
        final range = _rangeConfig();
        final activeComplaints = widget.store.supportTickets
            .where((ticket) => ticket.status != 'closed')
            .length;
        final alerts = _buildAlerts();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                EntranceMotion(
                  delay: const Duration(milliseconds: 80),
                  child: _MetricCard(
                    title: 'Products',
                    value: widget.store.allProducts.length.toDouble(),
                    formatter: (value) => value.toStringAsFixed(0),
                    icon: Icons.shopping_bag,
                    tone: _MetricTone.neutral,
                    animateKey: _countAnimationSeed,
                    animate: widget.active,
                  ),
                ),
                EntranceMotion(
                  delay: const Duration(milliseconds: 140),
                  child: _MetricCard(
                    title: 'Total Stock',
                    value: widget.store.totalStockCount.toDouble(),
                    formatter: (value) => value.toStringAsFixed(0),
                    icon: Icons.inventory_2,
                    tone: _MetricTone.neutral,
                    animateKey: _countAnimationSeed,
                    animate: widget.active,
                  ),
                ),
                EntranceMotion(
                  delay: const Duration(milliseconds: 200),
                  child: _MetricCard(
                    title: 'Low Stock',
                    value: widget.store.lowStockCount.toDouble(),
                    formatter: (value) => value.toStringAsFixed(0),
                    icon: Icons.warning_amber_rounded,
                    tone: widget.store.lowStockCount == 0
                        ? _MetricTone.success
                        : widget.store.lowStockCount >= 5
                        ? _MetricTone.danger
                        : _MetricTone.warning,
                    animateKey: _countAnimationSeed,
                    animate: widget.active,
                  ),
                ),
                EntranceMotion(
                  delay: const Duration(milliseconds: 260),
                  child: _MetricCard(
                    title: 'Complaints',
                    value: activeComplaints.toDouble(),
                    formatter: (value) => value.toStringAsFixed(0),
                    icon: Icons.report_problem_outlined,
                    tone: activeComplaints == 0
                        ? _MetricTone.success
                        : _MetricTone.danger,
                    animateKey: _countAnimationSeed,
                    animate: widget.active,
                  ),
                ),
                EntranceMotion(
                  delay: const Duration(milliseconds: 320),
                  child: _MetricCard(
                    title: 'Pending Orders',
                    value: _pendingOrders.toDouble(),
                    formatter: (value) => value.toStringAsFixed(0),
                    icon: Icons.timelapse,
                    tone: _pendingOrders >= 8
                        ? _MetricTone.warning
                        : _MetricTone.neutral,
                    animateKey: _countAnimationSeed,
                    animate: widget.active,
                  ),
                ),
                EntranceMotion(
                  delay: const Duration(milliseconds: 380),
                  child: _MetricCard(
                    title: 'Revenue',
                    value: widget.store.revenueTotal,
                    formatter: (value) => '\$${value.toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                    tone: _MetricTone.success,
                    animateKey: _countAnimationSeed,
                    animate: widget.active,
                  ),
                ),
              ],
            ),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 16),
              EntranceMotion(
                delay: const Duration(milliseconds: 440),
                child: Text(
                  'Active alerts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              ...alerts.asMap().entries.map(
                (entry) => EntranceMotion(
                  delay: Duration(milliseconds: 480 + (entry.key * 60)),
                  child: _AlertCard(alert: entry.value),
                ),
              ),
            ],
            const SizedBox(height: 20),
            EntranceMotion(
              delay: const Duration(milliseconds: 540),
              child: RangeSelector(
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
            ),
            const SizedBox(height: 12),
            EntranceMotion(
              delay: const Duration(milliseconds: 620),
              child: _ChartCard(
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
            ),
            const SizedBox(height: 20),
            EntranceMotion(
              delay: const Duration(milliseconds: 700),
              child: _ChartCard(
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
            ),
            const SizedBox(height: 20),
            EntranceMotion(
              delay: const Duration(milliseconds: 780),
              child: Text(
                'Latest Orders',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.store.allOrders.isEmpty)
              const EntranceMotion(
                delay: Duration(milliseconds: 820),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No orders yet.'),
                  ),
                ),
              )
            else
              ...widget.store.allOrders
                  .take(5)
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (entry) => EntranceMotion(
                      delay: Duration(milliseconds: 820 + (entry.key * 55)),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(entry.value.id),
                          subtitle: Text(
                            '${entry.value.customerEmail} - ${entry.value.status.name}',
                          ),
                          trailing: Text(
                            '\$${entry.value.total.toStringAsFixed(2)}',
                          ),
                        ),
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
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) => Dialog.fullscreen(
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
}

enum ChartRange { sevenDays, month, year, custom }

class RevenueRangeConfig {
  const RevenueRangeConfig({
    required this.start,
    required this.end,
    required this.bucketDays,
  });

  final DateTime start;
  final DateTime end;
  final int bucketDays;
}

class RangeSelector extends StatelessWidget {
  const RangeSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onPickCustom,
  });

  final ChartRange selected;
  final ValueChanged<ChartRange> onSelect;
  final VoidCallback onPickCustom;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('7 days'),
          selected: selected == ChartRange.sevenDays,
          onSelected: (_) => onSelect(ChartRange.sevenDays),
        ),
        ChoiceChip(
          label: const Text('1 month'),
          selected: selected == ChartRange.month,
          onSelected: (_) => onSelect(ChartRange.month),
        ),
        ChoiceChip(
          label: const Text('1 year'),
          selected: selected == ChartRange.year,
          onSelected: (_) => onSelect(ChartRange.year),
        ),
        ChoiceChip(
          label: const Text('Custom'),
          selected: selected == ChartRange.custom,
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
    return HoverLift(
      enabled: MediaQuery.of(context).size.width >= 900,
      hoverOffset: 4,
      hoverScale: 1.004,
      hoverElevation: 18,
      normalElevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Card(
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
      ),
    );
  }
}

class RevenueChart extends StatefulWidget {
  const RevenueChart({super.key, required this.orders, required this.range});

  final List<OrderRecord> orders;
  final RevenueRangeConfig range;

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart>
    with SingleTickerProviderStateMixin {
  int? _hoveredIndex;
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant RevenueChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orders != widget.orders || oldWidget.range != widget.range) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _moneyText(double value) => '\$${value.toStringAsFixed(2)}';

  List<double> _moneyScale(double maxValue) {
    const steps = 4;
    return List.generate(steps + 1, (index) => maxValue * (1 - index / steps));
  }

  List<String?> _visibleDateLabels(List<String> labels, int maxLabels) {
    if (labels.isEmpty) {
      return const [];
    }

    final result = List<String?>.filled(labels.length, null);
    final step = (labels.length / maxLabels).ceil().clamp(1, labels.length);
    for (var i = 0; i < labels.length; i += 1) {
      if (i == 0 || i == labels.length - 1 || i % step == 0) {
        result[i] = labels[i];
      }
    }
    return result;
  }

  List<_ChartPoint> _bucketedTotals(
    List<OrderRecord> orders,
    RevenueRangeConfig range,
  ) {
    final totalDays = range.end.difference(range.start).inDays.abs() + 1;
    final bucketDays = range.bucketDays.clamp(1, totalDays);
    final buckets = (totalDays / bucketDays).ceil();
    final totals = List<double>.filled(buckets, 0);

    for (final order in orders) {
      final index =
          order.createdAt.difference(range.start).inDays ~/ bucketDays;
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

  @override
  Widget build(BuildContext context) {
    final data = _bucketedTotals(widget.orders, widget.range);
    final maxValue = data.isEmpty
        ? 1.0
        : data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue == 0 ? 1.0 : maxValue;

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final maxLabels = width.isFinite
                ? (width / 56).floor().clamp(2, data.isEmpty ? 2 : data.length)
                : data.length;
            final visibleLabels = _visibleDateLabels(
              data.map((e) => e.label).toList(),
              maxLabels,
            );
            final moneyLabels = _moneyScale(safeMax);

            return Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: moneyLabels
                              .map(
                                (value) => Text(
                                  '\$${value.toStringAsFixed(0)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, chartConstraints) {
                            final chartWidth = chartConstraints.maxWidth;
                            final chartHeight = chartConstraints.maxHeight;

                            void updateHover(Offset localPosition) {
                              if (data.isEmpty) {
                                return;
                              }
                              final clampedX = localPosition.dx.clamp(
                                0.0,
                                chartWidth,
                              );
                              final index = data.length <= 1
                                  ? 0
                                  : ((clampedX / chartWidth) * (data.length - 1))
                                        .round()
                                        .clamp(0, data.length - 1);
                              if (_hoveredIndex != index) {
                                setState(() => _hoveredIndex = index);
                              }
                            }

                            final hoveredPoint =
                                _hoveredIndex != null && _hoveredIndex! < data.length
                                ? data[_hoveredIndex!]
                                : null;
                            final hoveredX =
                                _hoveredIndex == null || data.length <= 1
                                ? 0.0
                                : (chartWidth / (data.length - 1)) * _hoveredIndex!;
                            final hoveredY = hoveredPoint == null
                                ? 0.0
                                : chartHeight -
                                      (hoveredPoint.value / safeMax) * chartHeight;

                            return MouseRegion(
                              onExit: (_) => setState(() => _hoveredIndex = null),
                              onHover: (event) => updateHover(event.localPosition),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) =>
                                    updateHover(details.localPosition),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CustomPaint(
                                      painter: _LineChartPainter(
                                        points: data.map((e) => e.value).toList(),
                                        maxValue: safeMax,
                                        color: Theme.of(context).colorScheme.primary,
                                        highlightedIndex: _hoveredIndex,
                                        progress: _progress.value,
                                      ),
                                      child: const SizedBox.expand(),
                                    ),
                                    if (hoveredPoint != null)
                                      Positioned(
                                        left: (hoveredX - 56).clamp(
                                          0.0,
                                          chartWidth - 112,
                                        ),
                                        top: (hoveredY - 54).clamp(
                                          0.0,
                                          chartHeight - 34,
                                        ),
                                        child: Opacity(
                                          opacity: _progress.value,
                                          child: Container(
                                            width: 112,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outlineVariant,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  hoveredPoint.label,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _moneyText(hoveredPoint.value),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(width: 64),
                    Expanded(
                      child: Row(
                        children: visibleLabels
                            .map(
                              (label) => Expanded(
                                child: Text(
                                  label ?? '',
                                  textAlign: label == visibleLabels.first
                                      ? TextAlign.left
                                      : label == visibleLabels.last
                                      ? TextAlign.right
                                      : TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
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
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: widthFactor),
              duration: Duration(milliseconds: 600 + (index * 100)),
              curve: Curves.easeInOutCubic,
              builder: (context, animatedWidth, child) {
                return Stack(
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: animatedWidth,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 2),
            Text(
              '${item.value} sold',
              style: Theme.of(context).textTheme.bodySmall,
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
    required this.formatter,
    required this.icon,
    required this.tone,
    required this.animateKey,
    required this.animate,
  });

  final String title;
  final double value;
  final String Function(double value) formatter;
  final IconData icon;
  final _MetricTone tone;
  final int animateKey;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (background, foreground) = switch (tone) {
      _MetricTone.success => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      _MetricTone.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _MetricTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
      _MetricTone.neutral => (scheme.surfaceContainerHighest, scheme.onSurface),
    };

    return SizedBox(
      width: 170,
      child: HoverLift(
        enabled: MediaQuery.of(context).size.width >= 900,
        hoverOffset: 5,
        hoverScale: 1.01,
        hoverElevation: 20,
        normalElevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          color: background,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: foreground),
                const SizedBox(height: 10),
                Text(title, style: TextStyle(color: foreground)),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  key: ValueKey('$title-$animateKey-$value'),
                  tween: Tween<double>(begin: 0, end: value),
                  duration: animate
                      ? const Duration(milliseconds: 900)
                      : Duration.zero,
                  curve: Curves.easeInOutCubic,
                  builder: (context, animatedValue, child) {
                    return Text(
                      formatter(animatedValue),
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: foreground),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _MetricTone { neutral, success, warning, danger }

class _DashboardAlert {
  const _DashboardAlert({
    required this.title,
    required this.message,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String message;
  final IconData icon;
  final _MetricTone tone;
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final _DashboardAlert alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (background, foreground, border) = switch (alert.tone) {
      _MetricTone.success => (
        scheme.secondaryContainer.withValues(alpha: 0.8),
        scheme.onSecondaryContainer,
        scheme.secondary.withValues(alpha: 0.3),
      ),
      _MetricTone.warning => (
        scheme.tertiaryContainer.withValues(alpha: 0.72),
        scheme.onTertiaryContainer,
        scheme.tertiary.withValues(alpha: 0.35),
      ),
      _MetricTone.danger => (
        scheme.errorContainer.withValues(alpha: 0.72),
        scheme.onErrorContainer,
        scheme.error.withValues(alpha: 0.35),
      ),
      _MetricTone.neutral => (
        scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        scheme.onSurface,
        scheme.outlineVariant.withValues(alpha: 0.35),
      ),
    };

    return HoverLift(
      enabled: MediaQuery.of(context).size.width >= 900,
      hoverOffset: 4,
      hoverScale: 1.005,
      hoverElevation: 18,
      normalElevation: 6,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(alert.icon, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: foreground),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.points,
    required this.maxValue,
    required this.color,
    required this.progress,
    this.highlightedIndex,
  });

  final List<double> points;
  final double maxValue;
  final Color color;
  final double progress;
  final int? highlightedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final safeMax = maxValue <= 0 ? 1 : maxValue;

    final axisPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.bottom),
      axisPaint,
    );
    for (var i = 1; i <= 3; i += 1) {
      final y = rect.top + (rect.height / 4) * i;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), axisPaint);
    }
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
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width * progress, rect.height),
    );
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
        if (highlightedIndex == i) {
          canvas.drawCircle(
            Offset(x, y),
            7,
            Paint()
              ..color = color.withValues(alpha: 0.16)
              ..style = PaintingStyle.fill,
          );
          canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = color);
          canvas.drawLine(
            Offset(x, rect.top),
            Offset(x, rect.bottom),
            Paint()
              ..color = color.withValues(alpha: 0.18)
              ..strokeWidth = 1,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.highlightedIndex != highlightedIndex;
}

class _ChartPoint {
  const _ChartPoint({required this.label, required this.value});

  final String label;
  final double value;
}
