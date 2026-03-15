import 'package:flutter/material.dart';

import '../store/grocery_store_state.dart';
import '../widgets/theme_mode_menu.dart';
import 'dashboard.dart';
import 'coupons.dart';
import 'inventory.dart';
import 'order_management.dart';
import 'product_management.dart';
import 'sales_report.dart';
import 'support_inbox.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({
    super.key,
    required this.store,
    required this.onLogout,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final GroceryStoreState store;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;
  String? _lastAlertSignature;
  bool _alertOpen = false;

  String get _title {
    switch (_selectedIndex) {
      case 0:
        return 'Admin Dashboard';
      case 1:
        return 'Products';
      case 2:
        return 'Inventory';
      case 3:
        return 'Orders';
      case 4:
        return 'Sales Report';
      case 5:
        return 'Coupons';
      default:
        return 'Support';
    }
  }

  List<_NavItem> get _navItems => const [
    _NavItem('Dashboard', Icons.dashboard),
    _NavItem('Products', Icons.shopping_bag),
    _NavItem('Inventory', Icons.inventory_2),
    _NavItem('Orders', Icons.receipt_long),
    _NavItem('Sales', Icons.bar_chart),
    _NavItem('Coupons', Icons.confirmation_number_outlined),
    _NavItem('Support', Icons.support_agent),
  ];

  List<_AdminAlertSummary> _activeAlerts() {
    final lowStock = widget.store.lowStockCount;
    final openComplaints = widget.store.supportTickets
        .where((ticket) => ticket.status != 'closed')
        .length;
    final pendingOrders = widget.store.allOrders
        .where((order) => order.status.name == 'pending')
        .length;

    final alerts = <_AdminAlertSummary>[];
    if (openComplaints > 0) {
      alerts.add(
        _AdminAlertSummary(
          title: 'Customer complaints need attention',
          message:
              '$openComplaints support ticket${openComplaints == 1 ? '' : 's'} still need admin action.',
          icon: Icons.report_problem_outlined,
          tone: _AlertTone.danger,
        ),
      );
    }
    if (lowStock > 0) {
      alerts.add(
        _AdminAlertSummary(
          title: 'Low stock warning',
          message:
              '$lowStock product${lowStock == 1 ? '' : 's'} are running low and may need restocking.',
          icon: Icons.inventory_2_outlined,
          tone: lowStock >= 5 ? _AlertTone.danger : _AlertTone.warning,
        ),
      );
    }
    if (pendingOrders >= 8) {
      alerts.add(
        _AdminAlertSummary(
          title: 'Pending orders are building up',
          message:
              '$pendingOrders orders are still pending. Review fulfillment so delivery does not slip.',
          icon: Icons.timelapse_outlined,
          tone: _AlertTone.warning,
        ),
      );
    }
    return alerts;
  }

  void _maybeShowAlerts() {
    final alerts = _activeAlerts();
    final signature = alerts
        .map((alert) => '${alert.title}:${alert.message}')
        .join('|');

    if (alerts.isEmpty) {
      _lastAlertSignature = null;
      return;
    }
    if (_alertOpen || signature == _lastAlertSignature) {
      return;
    }

    _lastAlertSignature = signature;
    _alertOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _alertOpen = false;
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => _AdminAlertDialog(alerts: alerts),
      );

      if (mounted) {
        _alertOpen = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        _maybeShowAlerts();

        final isMobile = MediaQuery.of(context).size.width < 700;
        final useRail = !isMobile && _navItems.length > 5;

        final navList = ListView.builder(
          itemCount: _navItems.length,
          itemBuilder: (context, index) {
            final item = _navItems[index];
            return ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              selected: _selectedIndex == index,
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
                if (isMobile) {
                  Navigator.of(context).pop();
                }
              },
            );
          },
        );

        final content = IndexedStack(
          index: _selectedIndex,
          children: [
            AdminDashboardPage(store: widget.store),
            ProductManagementPage(store: widget.store),
            InventoryPage(store: widget.store),
            OrderManagementPage(store: widget.store),
            SalesReportPage(store: widget.store),
            CouponManagementPage(store: widget.store),
            SupportInboxPage(store: widget.store),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              ThemeModeMenu(
                themeMode: widget.themeMode,
                onChanged: widget.onThemeModeChanged,
              ),
              IconButton(
                onPressed: widget.onLogout,
                tooltip: 'Logout',
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          drawer: isMobile ? Drawer(child: SafeArea(child: navList)) : null,
          body: useRail
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      labelType: NavigationRailLabelType.all,
                      destinations: _navItems
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.icon),
                              label: Text(item.label),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: useRail || isMobile
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  destinations: _navItems
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}

enum _AlertTone { warning, danger }

class _AdminAlertSummary {
  const _AdminAlertSummary({
    required this.title,
    required this.message,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String message;
  final IconData icon;
  final _AlertTone tone;
}

class _AdminAlertDialog extends StatelessWidget {
  const _AdminAlertDialog({required this.alerts});

  final List<_AdminAlertSummary> alerts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color toneColor(_AlertTone tone) {
      return tone == _AlertTone.danger ? scheme.error : scheme.tertiary;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Admin alerts'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: alerts.map((alert) {
            final color = toneColor(alert.tone);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.26)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(alert.icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert.message,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Review dashboard'),
        ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
