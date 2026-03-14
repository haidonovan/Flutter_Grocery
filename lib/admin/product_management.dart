import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';
import 'add_product.dart';
import '../widgets/skeleton.dart';

class ProductManagementPage extends StatelessWidget {
  const ProductManagementPage({super.key, required this.store});

  final GroceryStoreState store;

  Future<void> _addProduct(BuildContext context) async {
    final data = await Navigator.of(context).push<ProductFormData>(
      MaterialPageRoute<ProductFormData>(
        builder: (_) => AddProductPage(
          onUploadImage: store.uploadImage,
          categories: store.categories,
        ),
      ),
    );

    if (data == null) {
      return;
    }

    store.addProduct(
      name: data.name,
      category: data.category,
      description: data.description,
      price: data.price,
      discountPercent: data.discountPercent,
      discountStart: data.discountStart,
      discountEnd: data.discountEnd,
      stock: data.stock,
      imageUrl: data.imageUrl,
    );
  }

  Future<void> _editProduct(BuildContext context, Product product) async {
    final data = await Navigator.of(context).push<ProductFormData>(
      MaterialPageRoute<ProductFormData>(
        builder: (_) => AddProductPage(
          initialProduct: product,
          onUploadImage: store.uploadImage,
          categories: store.categories,
        ),
      ),
    );

    if (data == null) {
      return;
    }

    store.updateProduct(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (store.isLoadingProducts) {
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: 6,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SkeletonBox(height: 72),
            ),
          );
        }
        return Scaffold(
          body: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: store.allProducts.length,
            itemBuilder: (context, index) {
              final product = store.allProducts[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(product.imageUrl),
                  ),
                  title: Text(product.name),
                  subtitle: Text(
                    product.discountPercent > 0
                        ? '${product.category} - \$${product.discountedPrice.toStringAsFixed(2)} (${product.discountPercent.toStringAsFixed(0)}% off)'
                        : '${product.category} - \$${product.price.toStringAsFixed(2)}',
                  ),
                  trailing: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: product.isActive,
                          onChanged: (value) {
                            store.toggleProductStatus(product.id, value);
                          },
                        ),
                        IconButton(
                          onPressed: () => _editProduct(context, product),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () {
                            store.deleteProduct(product.id);
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addProduct(context),
            icon: const Icon(Icons.add),
            label: const Text('Add product'),
          ),
        );
      },
    );
  }
}
