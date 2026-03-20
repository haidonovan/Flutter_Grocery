import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';
import '../utils/csv_export.dart';
import '../widgets/entrance_motion.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.store});

  final GroceryStoreState store;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  static const String _inventoryCsvTemplate =
      'productId,quantityAdded\n'
      'p_2da7d0d3-8d1c-49bf-9429-3886a77a20f2,12';

  String _query = '';
  String _stockFilter = 'All';
  String _sort = 'Lowest stock';
  DateTimeRange? _restockRange;

  int _countCsvPreviewRows(String rawCsv) {
    final normalized = rawCsv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length <= 1) {
      return 0;
    }
    return lines.length - 1;
  }

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

  Future<void> _importInventory(BuildContext context) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    var isSubmitting = false;
    String? errorText;

    final resultMessage = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final previewRows = _countCsvPreviewRows(controller.text);

          return EntranceMotion(
            duration: const Duration(milliseconds: 420),
            beginOffset: const Offset(0.06, 0),
            child: AlertDialog(
              title: const Text('Import inventory from CSV'),
              content: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paste restock rows here. Required columns: productId, quantityAdded.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SelectableText(
                          _inventoryCsvTemplate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final result = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: const ['csv'],
                                          withData: true,
                                        );
                                    if (result == null ||
                                        result.files.isEmpty ||
                                        !context.mounted) {
                                      return;
                                    }

                                    final file = result.files.single;
                                    final bytes = file.bytes;
                                    if (bytes == null) {
                                      setDialogState(() {
                                        errorText =
                                            'Could not read the selected CSV file.';
                                      });
                                      return;
                                    }

                                    controller.text = utf8.decode(bytes);
                                    setDialogState(() {
                                      errorText = null;
                                    });

                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Loaded ${file.name} for import.',
                                        ),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.attach_file_outlined),
                            label: const Text('Choose CSV file'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                const ClipboardData(
                                  text: _inventoryCsvTemplate,
                                ),
                              );
                              if (!context.mounted) {
                                return;
                              }
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Inventory template copied.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_all_outlined),
                            label: const Text('Copy template'),
                          ),
                          TextButton(
                            onPressed: () {
                              controller.text = _inventoryCsvTemplate;
                              setDialogState(() {
                                errorText = null;
                              });
                            },
                            child: const Text('Use sample'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          previewRows == 0
                              ? 'No inventory rows detected yet.'
                              : '$previewRows inventory row${previewRows == 1 ? '' : 's'} ready to import.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        minLines: 8,
                        maxLines: 14,
                        onChanged: (_) {
                          setDialogState(() {
                            errorText = null;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Paste inventory CSV here',
                          alignLabelWithHint: true,
                          errorText: errorText,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (controller.text.trim().isEmpty) {
                            setDialogState(() {
                              errorText = 'Paste CSV content first.';
                            });
                            return;
                          }
                          if (previewRows == 0) {
                            setDialogState(() {
                              errorText =
                                  'No inventory rows were found under the header.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorText = null;
                          });

                          final result = await widget.store.importInventoryCsv(
                            controller.text,
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }

                          if (!result.success) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = result.message ?? 'Import failed.';
                            });
                            return;
                          }

                          Navigator.of(dialogContext).pop(result.message);
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_upload_outlined),
                  label: Text(
                    isSubmitting
                        ? 'Importing...'
                        : previewRows == 0
                        ? 'Import'
                        : 'Import $previewRows',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (!mounted || resultMessage == null) {
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(resultMessage)));
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
    final success = await exportCsv(
      csvFilename('inventory_export'),
      buildCsv(rows),
    );
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
                    onPressed: () => _importInventory(context),
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import CSV'),
                  ),
                  const SizedBox(width: 8),
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
