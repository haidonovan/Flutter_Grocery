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

  @override
  Widget build(BuildContext context) {
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
      drawer: isMobile
          ? Drawer(
              child: SafeArea(child: navList),
            )
          : null,
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
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
