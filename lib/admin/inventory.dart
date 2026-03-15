import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';
import '../utils/csv_export.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.store});

  final GroceryStoreState store;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String _query = '';
  String _stockFilter = 'All';
  String _sort = 'Lowest stock';
  DateTimeRange? _restockRange;

  Future<void> _restock(BuildContext context, Product product) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final value = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Restock ${product.name}'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity to add',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final qty = int.tryParse(controller.text.trim());
                Navigator.of(context).pop(qty);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (value != null && value > 0) {
      try {
        await widget.store.restockProduct(product.id, value);
        if (!mounted) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text('${product.name} restocked by $value.')),
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _pickRestockRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _restockRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() {
        _restockRange = picked;
      });
    }
  }

  List<Product> _filteredProducts(List<Product> products) {
    final query = _query.trim().toLowerCase();
    final filtered = products.where((product) {
      if (_stockFilter == 'Low stock' && product.stock > 5) {
        return false;
      }
      if (_stockFilter == 'Out of stock' && product.stock > 0) {
        return false;
      }
      if (_stockFilter == 'Healthy stock' && product.stock <= 5) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case 'Highest stock':
        filtered.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      case 'Name A-Z':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      default:
        filtered.sort((a, b) => a.stock.compareTo(b.stock));
    }
    return filtered;
  }

  List<RestockRecord> _filteredRestocks(List<RestockRecord> entries) {
    final query = _query.trim().toLowerCase();
    return entries.where((entry) {
      if (_restockRange != null) {
        final date = entry.createdAt;
        if (date.isBefore(_restockRange!.start) ||
            date.isAfter(_restockRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }
      if (query.isEmpty) {
        return true;
      }
      return entry.productName.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _exportInventory(List<Product> products) async {
    final rows = <List<String>>[
      ['Product ID', 'Name', 'Category', 'Stock', 'Active'],
      ...products.map(
        (product) => [
          product.id,
          product.name,
          product.category,
          product.stock.toString(),
          product.isActive ? 'Yes' : 'No',
        ],
      ),
    ];
    final success = await exportCsv('inventory_export.csv', buildCsv(rows));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Inventory CSV downloaded.'
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
        final products = _filteredProducts(widget.store.allProducts);
        final restocks = _filteredRestocks(widget.store.restockHistory);
        final scheme = Theme.of(context).colorScheme;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final search = TextField(
                    decoration: InputDecoration(
                      hintText: 'Search product or category',
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

                  final stockFilter = DropdownButtonFormField<String>(
                    initialValue: _stockFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All stock')),
                      DropdownMenuItem(
                        value: 'Low stock',
                        child: Text('Low stock'),
                      ),
                      DropdownMenuItem(
                        value: 'Out of stock',
                        child: Text('Out of stock'),
                      ),
                      DropdownMenuItem(
                        value: 'Healthy stock',
                        child: Text('Healthy stock'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _stockFilter = value);
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
                      DropdownMenuItem(
                        value: 'Lowest stock',
                        child: Text('Lowest stock'),
                      ),
                      DropdownMenuItem(
                        value: 'Highest stock',
                        child: Text('Highest stock'),
                      ),
                      DropdownMenuItem(
                        value: 'Name A-Z',
                        child: Text('Name A-Z'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _sort = value);
                      }
                    },
                  );

                  final dateText = _restockRange == null
                      ? 'Restock date'
                      : '${_restockRange!.start.month}/${_restockRange!.start.day} - ${_restockRange!.end.month}/${_restockRange!.end.day}';

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        search,
                        const SizedBox(height: 10),
                        stockFilter,
                        const SizedBox(height: 10),
                        sortField,
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickRestockRange,
                              icon: const Icon(Icons.date_range),
                              label: Text(dateText),
                            ),
                            if (_restockRange != null)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _restockRange = null),
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
                          Expanded(child: stockFilter),
                          const SizedBox(width: 10),
                          Expanded(child: sortField),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _pickRestockRange,
                            icon: const Icon(Icons.date_range),
                            label: Text(dateText),
                          ),
                          if (_restockRange != null)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _restockRange = null),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Text(
                    '${products.length} product${products.length == 1 ? '' : 's'}',
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _exportInventory(products),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ...products.map(
                    (product) => Card(
                      child: ListTile(
                        title: Text(product.name),
                        subtitle: Text('Category: ${product.category}'),
                        trailing: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Stock ${product.stock}',
                                style: TextStyle(
                                  color: product.stock <= 0
                                      ? Colors.red
                                      : product.stock <= 5
                                      ? Colors.orange
                                      : Colors.green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.tonal(
                                onPressed: () => _restock(context, product),
                                child: const Text('Restock'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Recent restocks',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (restocks.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No restock records for this filter.'),
                      ),
                    )
                  else
                    ...restocks
                        .take(12)
                        .map(
                          (entry) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.add_box_outlined),
                              title: Text(entry.productName),
                              subtitle: Text(
                                entry.createdAt.toLocal().toString(),
                              ),
                              trailing: Text('+${entry.quantityAdded}'),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
