import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';

class CouponManagementPage extends StatelessWidget {
  const CouponManagementPage({super.key, required this.store});

  final GroceryStoreState store;

  Future<void> _openCreateDialog(BuildContext context) async {
    final codeController = TextEditingController();
    final descriptionController = TextEditingController();
    final userEmailController = TextEditingController();
    String type = 'percent';
    String audience = 'all';
    final valueController = TextEditingController();
    DateTime? startsAt;
    DateTime? endsAt;

    Future<void> pickDate(bool isStart) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 3),
      );
      if (picked != null) {
        if (isStart) {
          startsAt = picked;
        } else {
          endsAt = picked;
        }
      }
    }

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create coupon'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: audience,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Everyone')),
                  DropdownMenuItem(value: 'user', child: Text('Specific user')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    audience = value;
                  }
                },
              ),
              const SizedBox(height: 8),
              if (audience == 'user')
                TextField(
                  controller: userEmailController,
                  decoration: const InputDecoration(labelText: 'User email'),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('Percent')),
                  DropdownMenuItem(value: 'amount', child: Text('Amount')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    type = value;
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Value'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => pickDate(true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        startsAt == null
                            ? 'Start date'
                            : startsAt!.toLocal().toString().split(' ').first,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => pickDate(false),
                      icon: const Icon(Icons.event),
                      label: Text(
                        endsAt == null
                            ? 'End date'
                            : endsAt!.toLocal().toString().split(' ').first,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (shouldCreate == true) {
      final value = double.tryParse(valueController.text.trim()) ?? 0;
      await store.createCoupon(
        code: codeController.text.trim(),
        type: type,
        value: value,
        audience: audience,
        description: descriptionController.text.trim(),
        startsAt: startsAt,
        endsAt: endsAt,
        userEmail: userEmailController.text.trim(),
      );
    }
  }

  Future<void> _openEditDialog(BuildContext context, Coupon coupon) async {
    String type = coupon.type;
    String audience = coupon.audience ?? 'all';
    final valueController = TextEditingController(
      text: coupon.value.toStringAsFixed(2),
    );
    final descriptionController = TextEditingController(
      text: coupon.description ?? '',
    );
    final userEmailController = TextEditingController(
      text: coupon.userEmail ?? '',
    );
    bool isActive = coupon.isActive;
    DateTime? startsAt = coupon.startsAt;
    DateTime? endsAt = coupon.endsAt;

    Future<void> pickDate(bool isStart) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 3),
      );
      if (picked != null) {
        if (isStart) {
          startsAt = picked;
        } else {
          endsAt = picked;
        }
      }
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${coupon.code}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Active'),
                value: isActive,
                onChanged: (value) {
                  isActive = value;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: audience,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Everyone')),
                  DropdownMenuItem(value: 'user', child: Text('Specific user')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    audience = value;
                  }
                },
              ),
              const SizedBox(height: 8),
              if (audience == 'user')
                TextField(
                  controller: userEmailController,
                  decoration: const InputDecoration(labelText: 'User email'),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('Percent')),
                  DropdownMenuItem(value: 'amount', child: Text('Amount')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    type = value;
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Value'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => pickDate(true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        startsAt == null
                            ? 'Start date'
                            : startsAt!.toLocal().toString().split(' ').first,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => pickDate(false),
                      icon: const Icon(Icons.event),
                      label: Text(
                        endsAt == null
                            ? 'End date'
                            : endsAt!.toLocal().toString().split(' ').first,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      final value = double.tryParse(valueController.text.trim()) ?? coupon.value;
      await store.updateCoupon(
        id: coupon.id,
        isActive: isActive,
        type: type,
        value: value,
        audience: audience,
        description: descriptionController.text.trim(),
        startsAt: startsAt,
        endsAt: endsAt,
        userEmail: userEmailController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          body: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: store.coupons.length,
            itemBuilder: (context, index) {
              final coupon = store.coupons[index];
              final valueLabel = coupon.type == 'percent'
                  ? '${coupon.value.toStringAsFixed(0)}%'
                  : '\$${coupon.value.toStringAsFixed(2)}';
              final expiry = coupon.endsAt == null
                  ? 'No expiry'
                  : 'Ends ${coupon.endsAt!.toLocal().toString().split(' ').first}';
              return Card(
                child: ListTile(
                  title: Text(coupon.code),
                  subtitle: Text('$valueLabel • $expiry'),
                  trailing: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: coupon.isActive,
                          onChanged: (value) {
                            store.updateCoupon(
                              id: coupon.id,
                              isActive: value,
                              type: coupon.type,
                              value: coupon.value,
                              audience: coupon.audience ?? 'all',
                              description: coupon.description ?? '',
                              startsAt: coupon.startsAt,
                              endsAt: coupon.endsAt,
                              userEmail: coupon.userEmail,
                            );
                          },
                        ),
                        IconButton(
                          onPressed: () => _openEditDialog(context, coupon),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => store.deleteCoupon(coupon.id),
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
            onPressed: () => _openCreateDialog(context),
            icon: const Icon(Icons.confirmation_number_outlined),
            label: const Text('Add coupon'),
          ),
        );
      },
    );
  }
}
