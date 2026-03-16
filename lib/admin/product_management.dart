import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';
import '../utils/csv_export.dart';
import '../widgets/app_page_route.dart';
import '../widgets/entrance_motion.dart';
import 'add_product.dart';

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({super.key, required this.store});

  final GroceryStoreState store;

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  static const String _csvTemplate =
      'name,category,description,price,stock,imageUrl,discountPercent,discountStart,discountEnd,isActive\n'
      'Fresh Apples,Fruit,Crisp red apples,4.99,120,https://example.com/apples.jpg,10,2026-03-15T00:00:00.000Z,2026-03-31T23:59:59.000Z,true';

  String _query = '';
  String _selectedCategory = 'All';
  String _sort = 'Newest';
  final Set<String> _togglingProductIds = <String>{};
  final Set<String> _deletingProductIds = <String>{};
  bool _savingProduct = false;

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

  Future<void> _addProduct(BuildContext context) async {
    final data = await Navigator.of(context).push<ProductFormData>(
      AppPageRoute<ProductFormData>(
        builder: (_) => AddProductPage(
          onUploadImage: widget.store.uploadImage,
          categories: widget.store.categories,
        ),
      ),
    );

    if (data == null) {
      return;
    }

    await _saveProductAction(
      () => widget.store.addProduct(
        name: data.name,
        category: data.category,
        description: data.description,
        price: data.price,
        discountPercent: data.discountPercent,
        discountStart: data.discountStart,
        discountEnd: data.discountEnd,
        stock: data.stock,
        imageUrl: data.imageUrl,
      ),
      successMessage: '"${data.name}" created.',
    );
  }

  Future<void> _editProduct(BuildContext context, Product product) async {
    final data = await Navigator.of(context).push<ProductFormData>(
      AppPageRoute<ProductFormData>(
        builder: (_) => AddProductPage(
          initialProduct: product,
          onUploadImage: widget.store.uploadImage,
          categories: widget.store.categories,
        ),
      ),
    );

    if (data == null) {
      return;
    }

    await _saveProductAction(
      () => widget.store.updateProduct(
        product.copyWith(
          name: data.name,
          category: data.category,
          description: data.description,
          price: data.price,
          discountPercent: data.discountPercent,
          discountStart: data.discountStart,
          discountEnd: data.discountEnd,
          stock: data.stock,
          imageUrl: data.imageUrl,
        ),
      ),
      successMessage: '"${data.name}" updated.',
    );
  }

  Future<void> _deleteProduct(BuildContext context, Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'Delete "${product.name}" from the catalog? This only removes that one product.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    setState(() {
      _deletingProductIds.add(product.id);
    });

    try {
      await widget.store.deleteProduct(product.id);
      if (!mounted) {
        return;
      }

      final categoryStillExists = widget.store.allProducts.any(
        (item) => item.category == _selectedCategory,
      );
      if (_selectedCategory != 'All' && !categoryStillExists) {
        setState(() {
          _selectedCategory = 'All';
        });
      }

      messenger.showSnackBar(
        SnackBar(content: Text('"${product.name}" deleted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _deletingProductIds.remove(product.id);
        });
      }
    }
  }

  Future<void> _toggleProductStatus(Product product, bool value) async {
    setState(() {
      _togglingProductIds.add(product.id);
    });
    try {
      await widget.store.toggleProductStatus(product.id, value);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '"${product.name}" is now active.'
                : '"${product.name}" was hidden from the storefront.',
          ),
        ),
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
          _togglingProductIds.remove(product.id);
        });
      }
    }
  }

  Future<void> _saveProductAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_savingProduct) {
      return;
    }

    setState(() {
      _savingProduct = true;
    });

    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
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
          _savingProduct = false;
        });
      }
    }
  }

  Future<void> _exportProducts(List<Product> products) async {
    final rows = <List<String>>[
      [
        'Product ID',
        'Name',
        'Category',
        'Description',
        'Price',
        'Discount Percent',
        'Discount Start',
        'Discount End',
        'Stock',
        'Active',
        'Image URL',
      ],
      ...products.map(
        (product) => [
          product.id,
          product.name,
          product.category,
          product.description,
          product.price.toStringAsFixed(2),
          product.discountPercent.toStringAsFixed(0),
          product.discountStart?.toIso8601String() ?? '',
          product.discountEnd?.toIso8601String() ?? '',
          product.stock.toString(),
          product.isActive ? 'Yes' : 'No',
          product.imageUrl,
        ],
      ),
    ];

    final success = await exportCsv(
      csvFilename('products_export'),
      buildCsv(rows),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Products CSV downloaded.'
              : 'CSV export is available on web builds.',
        ),
      ),
    );
  }

  Future<void> _importProducts(BuildContext context) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    var isSubmitting = false;
    String? errorText;

    final csv = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final previewRows = _countCsvPreviewRows(controller.text);

            return EntranceMotion(
              duration: const Duration(milliseconds: 420),
              beginOffset: const Offset(0.06, 0),
              child: AlertDialog(
                title: const Text('Import products from CSV'),
                content: SizedBox(
                  width: 680,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paste CSV rows here. Required columns: name, category, description, price, stock, imageUrl.',
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
                            _csvTemplate,
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
                                  const ClipboardData(text: _csvTemplate),
                                );
                                if (!context.mounted) {
                                  return;
                                }
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('CSV template copied.'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_all_outlined),
                              label: const Text('Copy template'),
                            ),
                            TextButton(
                              onPressed: () {
                                controller.text = _csvTemplate;
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
                            color: scheme.primaryContainer.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            previewRows == 0
                                ? 'No product rows detected yet.'
                                : '$previewRows product row${previewRows == 1 ? '' : 's'} ready to import.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          minLines: 10,
                          maxLines: 16,
                          onChanged: (_) {
                            setDialogState(() {
                              errorText = null;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Paste product CSV here',
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
                                    'No product rows were found under the header.';
                              });
                              return;
                            }

                            setDialogState(() {
                              isSubmitting = true;
                              errorText = null;
                            });

                            final result = await widget.store.importProductsCsv(
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
        );
      },
    );

    if (!mounted || csv == null) {
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(csv)));
  }

  List<String> _categories(List<String> categories) {
    final values = <String>{'All'};
    values.addAll(categories);
    return values.toList();
  }

  List<Product> _filterProducts(List<Product> products) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return products;
    }

    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query) ||
          product.id.toLowerCase().contains(query);
    }).toList();
  }

  List<Product> _sortProducts(List<Product> products) {
    switch (_sort) {
      case 'Name A-Z':
        return products..sort((a, b) => a.name.compareTo(b.name));
      case 'Name Z-A':
        return products..sort((a, b) => b.name.compareTo(a.name));
      case 'Category A-Z':
        return products..sort((a, b) => a.category.compareTo(b.category));
      case 'Category Z-A':
        return products..sort((a, b) => b.category.compareTo(a.category));
      case 'Price High-Low':
        return products..sort((a, b) => b.price.compareTo(a.price));
      case 'Price Low-High':
        return products..sort((a, b) => a.price.compareTo(b.price));
      case 'Stock':
        return products..sort((a, b) => b.stock.compareTo(a.stock));
      default:
        return products;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        if (widget.store.isLoadingProducts && widget.store.allProducts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = _categories(widget.store.categories);
        final products = _selectedCategory == 'All'
            ? widget.store.allProducts
            : widget.store.allProducts
                  .where((product) => product.category == _selectedCategory)
                  .toList();
        final sortedProducts = _sortProducts(_filterProducts([...products]));

        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final theme = Theme.of(context);
                    final scheme = theme.colorScheme;
                    final isCompact = constraints.maxWidth < 680;

                    final searchField = DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.surfaceContainerHighest,
                            scheme.primaryContainer.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText:
                              'Search product name, category, description, ID',
                          prefixIcon: Icon(Icons.search, color: scheme.primary),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _query = '';
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: scheme.primary.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                          });
                        },
                      ),
                    );

                    final categoryChips = SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final selected = category == _selectedCategory;
                          return ChoiceChip(
                            label: Text(category),
                            selected: selected,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                          );
                        },
                      ),
                    );

                    final sortDropdown = DropdownButtonFormField<String>(
                      initialValue: _sort,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Newest',
                          child: Text('Newest'),
                        ),
                        DropdownMenuItem(
                          value: 'Name A-Z',
                          child: Text('Name A-Z'),
                        ),
                        DropdownMenuItem(
                          value: 'Name Z-A',
                          child: Text('Name Z-A'),
                        ),
                        DropdownMenuItem(
                          value: 'Category A-Z',
                          child: Text('Category A-Z'),
                        ),
                        DropdownMenuItem(
                          value: 'Category Z-A',
                          child: Text('Category Z-A'),
                        ),
                        DropdownMenuItem(
                          value: 'Price Low-High',
                          child: Text('Price Low-High'),
                        ),
                        DropdownMenuItem(
                          value: 'Price High-Low',
                          child: Text('Price High-Low'),
                        ),
                        DropdownMenuItem(value: 'Stock', child: Text('Stock')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _sort = value;
                        });
                      },
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          searchField,
                          const SizedBox(height: 10),
                          categoryChips,
                          const SizedBox(height: 10),
                          SizedBox(height: 44, child: sortDropdown),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        searchField,
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: categoryChips),
                            const SizedBox(width: 12),
                            SizedBox(width: 240, child: sortDropdown),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Row(
                  children: [
                    Text(
                      '${sortedProducts.length} product${sortedProducts.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_query.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'for "$_query"',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                    if (_savingProduct) ...[
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _exportProducts(sortedProducts),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sortedProducts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 42,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No matching products found.',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.store.allProducts.isNotEmpty
                                    ? 'Your current search or category filter is hiding the remaining products.'
                                    : 'There are no products in the catalog right now.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (widget.store.allProducts.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _query = '';
                                      _selectedCategory = 'All';
                                      _sort = 'Newest';
                                    });
                                  },
                                  child: const Text('Clear filters'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: sortedProducts.length,
                        itemBuilder: (context, index) {
                          final product = sortedProducts[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 620;

                                  final image = CircleAvatar(
                                    radius: 24,
                                    backgroundImage: NetworkImage(
                                      product.imageUrl,
                                    ),
                                  );

                                  final details = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product.discountPercent > 0
                                            ? '${product.category} - \$${product.discountedPrice.toStringAsFixed(2)} (${product.discountPercent.toStringAsFixed(0)}% off)'
                                            : '${product.category} - \$${product.price.toStringAsFixed(2)}',
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _ProductChip(
                                            label: 'Stock ${product.stock}',
                                            color: product.stock <= 5
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.errorContainer
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .secondaryContainer,
                                            foreground: product.stock <= 5
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.onErrorContainer
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSecondaryContainer,
                                          ),
                                          _ProductChip(
                                            label: product.isActive
                                                ? 'Active'
                                                : 'Hidden',
                                            color: product.isActive
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primaryContainer
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                            foreground: product.isActive
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                        ],
                                      ),
                                    ],
                                  );

                                  final actions = Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      if (_togglingProductIds.contains(product.id))
                                        const SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: Padding(
                                            padding: EdgeInsets.all(8),
                                            child: CircularProgressIndicator(strokeWidth: 2.2),
                                          ),
                                        )
                                      else
                                        Switch(
                                          value: product.isActive,
                                          onChanged: (value) async {
                                            await _toggleProductStatus(
                                              product,
                                              value,
                                            );
                                          },
                                        ),
                                      IconButton(
                                        onPressed: () =>
                                            _editProduct(context, product),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      if (_deletingProductIds.contains(
                                        product.id,
                                      ))
                                        const SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: Padding(
                                            padding: EdgeInsets.all(8),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                            ),
                                          ),
                                        )
                                      else
                                        IconButton(
                                          onPressed: () =>
                                              _deleteProduct(context, product),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                    ],
                                  );

                                  if (compact) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            image,
                                            const SizedBox(width: 12),
                                            Expanded(child: details),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: actions,
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      image,
                                      const SizedBox(width: 12),
                                      Expanded(child: details),
                                      const SizedBox(width: 12),
                                      actions,
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'import_products',
                onPressed: () => _importProducts(context),
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import CSV'),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'add_product',
                onPressed: () => _addProduct(context),
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({
    required this.label,
    required this.color,
    required this.foreground,
  });

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: foreground),
      ),
    );
  }
}
