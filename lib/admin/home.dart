import 'package:flutter/material.dart';

import '../store/grocery_store_state.dart';
import 'dashboard.dart';
import 'inventory.dart';
import 'order_management.dart';
import 'product_management.dart';
import 'sales_report.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.store, required this.onLogout});

  final GroceryStoreState store;
  final VoidCallback onLogout;

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
      default:
        return 'Sales Report';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          AdminDashboardPage(store: widget.store),
          ProductManagementPage(store: widget.store),
          InventoryPage(store: widget.store),
          OrderManagementPage(store: widget.store),
          SalesReportPage(store: widget.store),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Sales'),
        ],
      ),
    );
  }
}
