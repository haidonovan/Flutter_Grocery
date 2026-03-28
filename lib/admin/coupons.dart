import 'dart:async';

import 'package:flutter/material.dart';

import '../client/models.dart';
import '../store/grocery_store_state.dart';
import '../utils/csv_export.dart';
import '../widgets/app_identity_avatar.dart';
import '../widgets/suggestion_search_field.dart';

class CouponManagementPage extends StatefulWidget {
  const CouponManagementPage({super.key, required this.store});

  final GroceryStoreState store;

  @override
  State<CouponManagementPage> createState() => _CouponManagementPageState();
}

class _CouponManagementPageState extends State<CouponManagementPage> {
  String _query = '';
  String _statusFilter = 'All';
  String _audienceFilter = 'All';
  String _sort = 'Newest';
  DateTimeRange? _dateRange;

  Future<void> _openCreateDialog(BuildContext context) async {
    final codeController = TextEditingController();
    final descriptionController = TextEditingController();
    String type = 'percent';
    String audience = 'all';
    String targetUserEmail = '';
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                    DropdownMenuItem(
                      value: 'user',
                      child: Text('Specific user'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        audience = value;
                        if (value != 'user') {
                          targetUserEmail = '';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (audience == 'user')
                  _CouponUserPickerField(
                    store: widget.store,
                    initialEmail: targetUserEmail,
                    onEmailChanged: (value) {
                      targetUserEmail = value.trim();
                    },
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
                      setDialogState(() => type = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await pickDate(true);
                        if (mounted) {
                          setDialogState(() {});
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        startsAt == null
                            ? 'Start date'
                            : startsAt!.toLocal().toString().split(' ').first,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await pickDate(false);
                        if (mounted) {
                          setDialogState(() {});
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text(
                        endsAt == null
                            ? 'End date'
                            : endsAt!.toLocal().toString().split(' ').first,
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
      ),
    );

    if (shouldCreate == true) {
      final value = double.tryParse(valueController.text.trim()) ?? 0;
      await _runCouponAction(() async {
        await widget.store.createCoupon(
          code: codeController.text.trim(),
          type: type,
          value: value,
          audience: audience,
          description: descriptionController.text.trim(),
          startsAt: startsAt,
          endsAt: endsAt,
          userEmail: targetUserEmail,
        );
      }, successMessage: 'Coupon created.');
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
    bool isActive = coupon.isActive;
    String targetUserEmail = coupon.userEmail ?? '';
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${coupon.code}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() => isActive = value);
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
                    DropdownMenuItem(
                      value: 'user',
                      child: Text('Specific user'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        audience = value;
                        if (value != 'user') {
                          targetUserEmail = '';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (audience == 'user')
                  _CouponUserPickerField(
                    store: widget.store,
                    initialEmail: targetUserEmail,
                    initialSelectedUser: coupon.targetUser,
                    onEmailChanged: (value) {
                      targetUserEmail = value.trim();
                    },
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
                      setDialogState(() => type = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await pickDate(true);
                        if (mounted) {
                          setDialogState(() {});
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        startsAt == null
                            ? 'Start date'
                            : startsAt!.toLocal().toString().split(' ').first,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await pickDate(false);
                        if (mounted) {
                          setDialogState(() {});
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text(
                        endsAt == null
                            ? 'End date'
                            : endsAt!.toLocal().toString().split(' ').first,
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
      ),
    );

    if (shouldSave == true) {
      final value =
          double.tryParse(valueController.text.trim()) ?? coupon.value;
      await _runCouponAction(() async {
        await widget.store.updateCoupon(
          id: coupon.id,
          isActive: isActive,
          type: type,
          value: value,
          audience: audience,
          description: descriptionController.text.trim(),
          startsAt: startsAt,
          endsAt: endsAt,
          userEmail: targetUserEmail,
        );
      }, successMessage: 'Coupon updated.');
    }
  }

  Future<void> _runCouponAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
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
    }
  }

  Future<void> _deleteCoupon(Coupon coupon) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${coupon.code}?'),
        content: const Text(
          'This removes that coupon code from the system. Existing orders will stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }

    final result = await widget.store.deleteCoupon(coupon.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ??
              (result.success ? 'Coupon deleted.' : 'Failed to delete coupon.'),
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 60)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  List<Coupon> _filteredCoupons(List<Coupon> coupons) {
    final query = _query.trim().toLowerCase();
    final filtered = coupons.where((coupon) {
      if (_statusFilter == 'Active' && !coupon.isActive) {
        return false;
      }
      if (_statusFilter == 'Inactive' && coupon.isActive) {
        return false;
      }
      if (_audienceFilter != 'All' &&
          (coupon.audience ?? 'all') != _audienceFilter) {
        return false;
      }
      if (_dateRange != null) {
        final starts = coupon.startsAt;
        final ends = coupon.endsAt;
        if (starts != null && starts.isAfter(_dateRange!.end)) {
          return false;
        }
        if (ends != null &&
            ends.isBefore(
              _dateRange!.start.subtract(const Duration(days: 1)),
            )) {
          return false;
        }
      }
      if (query.isEmpty) {
        return true;
      }
      return coupon.targetSearchText.toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case 'Code A-Z':
        filtered.sort((a, b) => a.code.compareTo(b.code));
        break;
      case 'Highest value':
        filtered.sort((a, b) => b.value.compareTo(a.value));
        break;
      case 'Lowest value':
        filtered.sort((a, b) => a.value.compareTo(b.value));
        break;
      default:
        filtered.sort((a, b) => b.id.compareTo(a.id));
    }
    return filtered;
  }

  List<Coupon> _couponSuggestions(List<Coupon> coupons) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return coupons
        .where((coupon) => coupon.targetSearchText.toLowerCase().contains(query))
        .take(8)
        .toList(growable: false);
  }

  Future<void> _exportCoupons(List<Coupon> coupons) async {
    final rows = <List<String>>[
      ['Code', 'Type', 'Value', 'Active', 'Audience', 'Target Name', 'User Email'],
      ...coupons.map(
        (coupon) => [
          coupon.code,
          coupon.type,
          coupon.value.toStringAsFixed(2),
          coupon.isActive ? 'Yes' : 'No',
          coupon.audience ?? 'all',
          coupon.targetDisplayName,
          coupon.userEmail ?? '',
        ],
      ),
    ];
    final success = await exportCsv(
      csvFilename('coupons_export'),
      buildCsv(rows),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? csvExportSuccessMessage('Coupons')
                : csvExportFailureMessage(),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final coupons = _filteredCoupons(widget.store.coupons);
        final couponSuggestions = _couponSuggestions(widget.store.coupons);
        final scheme = Theme.of(context).colorScheme;
        final hideAdminFileActions = MediaQuery.sizeOf(context).width < 760;

        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;

                    final search = SuggestionSearchField<Coupon>(
                      value: _query,
                      onChanged: (value) => setState(() => _query = value),
                      suggestions: couponSuggestions,
                      selectionTextBuilder: (coupon) => coupon.code,
                      decoration: InputDecoration(
                        hintText:
                            'Search code, description, customer name, or email',
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
                      itemBuilder: (context, coupon) {
                        final subtitle = coupon.isForEveryone
                            ? 'Everyone'
                            : coupon.userEmail ?? coupon.targetDisplayName;
                        return Row(
                          children: [
                            _CouponAudienceAvatar(coupon: coupon, size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    coupon.code,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );

                    final status = DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
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
                          value: 'All',
                          child: Text('All status'),
                        ),
                        DropdownMenuItem(
                          value: 'Active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'Inactive',
                          child: Text('Inactive'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _statusFilter = value);
                        }
                      },
                    );

                    final audience = DropdownButtonFormField<String>(
                      initialValue: _audienceFilter,
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
                          value: 'All',
                          child: Text('All audience'),
                        ),
                        DropdownMenuItem(value: 'all', child: Text('Everyone')),
                        DropdownMenuItem(
                          value: 'user',
                          child: Text('Specific user'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _audienceFilter = value);
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
                          value: 'Newest',
                          child: Text('Newest'),
                        ),
                        DropdownMenuItem(
                          value: 'Code A-Z',
                          child: Text('Code A-Z'),
                        ),
                        DropdownMenuItem(
                          value: 'Highest value',
                          child: Text('Highest value'),
                        ),
                        DropdownMenuItem(
                          value: 'Lowest value',
                          child: Text('Lowest value'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sort = value);
                        }
                      },
                    );

                    final dateText = _dateRange == null
                        ? 'Date range'
                        : '${_dateRange!.start.month}/${_dateRange!.start.day} - ${_dateRange!.end.month}/${_dateRange!.end.day}';

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          search,
                          const SizedBox(height: 10),
                          status,
                          const SizedBox(height: 10),
                          audience,
                          const SizedBox(height: 10),
                          sortField,
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickDateRange,
                                icon: const Icon(Icons.date_range),
                                label: Text(dateText),
                              ),
                              if (_dateRange != null)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _dateRange = null),
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
                            Expanded(child: status),
                            const SizedBox(width: 10),
                            Expanded(child: audience),
                            const SizedBox(width: 10),
                            Expanded(child: sortField),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: _pickDateRange,
                              icon: const Icon(Icons.date_range),
                              label: Text(dateText),
                            ),
                            if (_dateRange != null)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _dateRange = null),
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
                      '${coupons.length} coupon${coupons.length == 1 ? '' : 's'}',
                    ),
                    const Spacer(),
                    if (!hideAdminFileActions)
                      OutlinedButton.icon(
                        onPressed: () => _exportCoupons(coupons),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Export CSV'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: coupons.length,
                  itemBuilder: (context, index) {
                    final coupon = coupons[index];
                    final valueLabel = coupon.type == 'percent'
                        ? '${coupon.value.toStringAsFixed(0)}%'
                        : '\$${coupon.value.toStringAsFixed(2)}';
                    final expiry = coupon.endsAt == null
                        ? 'No expiry'
                        : 'Ends ${coupon.endsAt!.toLocal().toString().split(' ').first}';
                    return Card(
                      child: ListTile(
                        leading: _CouponAudienceAvatar(coupon: coupon, size: 44),
                        title: Text(coupon.code),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$valueLabel | $expiry'),
                            const SizedBox(height: 4),
                            Text(
                              coupon.targetDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (!coupon.isForEveryone &&
                                coupon.userEmail != null &&
                                coupon.targetDisplayName != coupon.userEmail)
                              Text(
                                coupon.userEmail!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                          ],
                        ),
                        trailing: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: coupon.isActive,
                                onChanged: (value) async {
                                  await _runCouponAction(
                                    () => widget.store.updateCoupon(
                                      id: coupon.id,
                                      isActive: value,
                                      type: coupon.type,
                                      value: coupon.value,
                                      audience: coupon.audience ?? 'all',
                                      description: coupon.description ?? '',
                                      startsAt: coupon.startsAt,
                                      endsAt: coupon.endsAt,
                                      userEmail: coupon.userEmail,
                                    ),
                                    successMessage: value
                                        ? 'Coupon activated.'
                                        : 'Coupon deactivated.',
                                  );
                                },
                              ),
                              IconButton(
                                onPressed: () =>
                                    _openEditDialog(context, coupon),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => _deleteCoupon(coupon),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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

class _CouponAudienceAvatar extends StatelessWidget {
  const _CouponAudienceAvatar({
    required this.coupon,
    required this.size,
  });

  final Coupon coupon;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (coupon.isForEveryone) {
      return AppIdentityAvatar(
        size: size,
        initials: 'EV',
        icon: Icons.groups_rounded,
      );
    }

    return AppIdentityAvatar(
      size: size,
      imageUrl: coupon.targetUser?.profileImageUrl,
      initials: coupon.targetUser?.initials ?? _emailInitials(coupon.userEmail),
    );
  }
}

class _CouponUserPickerField extends StatefulWidget {
  const _CouponUserPickerField({
    required this.store,
    required this.onEmailChanged,
    this.initialEmail = '',
    this.initialSelectedUser,
  });

  final GroceryStoreState store;
  final ValueChanged<String> onEmailChanged;
  final String initialEmail;
  final AppUserSummary? initialSelectedUser;

  @override
  State<_CouponUserPickerField> createState() => _CouponUserPickerFieldState();
}

class _CouponUserPickerFieldState extends State<_CouponUserPickerField> {
  Timer? _debounce;
  late String _query;
  AppUserSummary? _selectedUser;
  List<AppUserSummary> _suggestions = const [];
  bool _loading = false;
  String? _emptyStateText;

  @override
  void initState() {
    super.initState();
    _selectedUser = widget.initialSelectedUser;
    _query = widget.initialEmail;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _suggestions = const [];
        _loading = false;
        _emptyStateText = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _emptyStateText = null;
    });

    try {
      final users = await widget.store.searchUsers(trimmed);
      if (!mounted || _query.trim() != trimmed) {
        return;
      }
      setState(() {
        _suggestions = users;
        _loading = false;
        _emptyStateText =
            users.isEmpty ? 'No matching clients found yet.' : null;
      });
    } catch (_) {
      if (!mounted || _query.trim() != trimmed) {
        return;
      }
      setState(() {
        _suggestions = const [];
        _loading = false;
        _emptyStateText = 'Unable to load client suggestions right now.';
      });
    }
  }

  void _handleQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _query = value;
      _selectedUser = null;
    });
    widget.onEmailChanged(value.trim());
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _search(value);
    });
  }

  void _handleSelectedUser(AppUserSummary user) {
    _debounce?.cancel();
    setState(() {
      _selectedUser = user;
      _query = user.email;
      _suggestions = const [];
      _emptyStateText = null;
    });
    widget.onEmailChanged(user.email);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuggestionSearchField<AppUserSummary>(
          value: _query,
          onChanged: _handleQueryChanged,
          suggestions: _suggestions,
          loading: _loading,
          emptyStateText: _emptyStateText,
          selectionTextBuilder: (user) => user.email,
          decoration: const InputDecoration(
            labelText: 'Target client',
            hintText: 'Search by name or email',
          ),
          itemBuilder: (context, user) {
            return Row(
              children: [
                AppIdentityAvatar(
                  size: 38,
                  imageUrl: user.profileImageUrl,
                  initials: user.initials,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          onSelected: _handleSelectedUser,
        ),
        if (_selectedUser != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.42),
            ),
            child: Row(
              children: [
                AppIdentityAvatar(
                  size: 42,
                  imageUrl: _selectedUser!.profileImageUrl,
                  initials: _selectedUser!.initials,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedUser!.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedUser!.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Clear selection',
                  onPressed: () {
                    setState(() {
                      _selectedUser = null;
                      _query = '';
                      _suggestions = const [];
                      _emptyStateText = null;
                    });
                    widget.onEmailChanged('');
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String _emailInitials(String? email) {
  final trimmed = email?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.substring(0, 1).toUpperCase();
}


