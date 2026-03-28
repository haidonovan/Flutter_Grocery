import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../store/grocery_store_state.dart';
import '../widgets/animated_nav_items.dart';
import '../widgets/entrance_motion.dart';
import '../widgets/profile_image_picker.dart';
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
    required this.themeStyle,
    required this.onThemeModeChanged,
    required this.onThemeStyleChanged,
    required this.onThemeTriggerOrigin,
  });

  final GroceryStoreState store;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final AppThemeStyle themeStyle;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppThemeStyle> onThemeStyleChanged;
  final ValueChanged<Offset> onThemeTriggerOrigin;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;
  String? _lastAlertSignature;
  bool _alertOpen = false;
  bool _isManualRefreshing = false;

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

  Future<void> _refreshCurrentData() async {
    if (_isManualRefreshing) {
      return;
    }

    setState(() {
      _isManualRefreshing = true;
    });

    try {
      await widget.store.refreshAll();
    } finally {
      if (mounted) {
        setState(() {
          _isManualRefreshing = false;
        });
      }
    }
  }

  Widget _buildNavigationList({
    required bool closeDrawerOnTap,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
  }) {
    return ListView.builder(
      padding: padding,
      itemCount: _navItems.length,
      itemBuilder: (context, index) {
        final item = _navItems[index];
        return AnimatedNavTile(
          icon: item.icon,
          label: item.label,
          selected: _selectedIndex == index,
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
            if (closeDrawerOnTap) {
              Navigator.of(context).pop();
            }
          },
        );
      },
    );
  }

  Widget _buildNavigationPanel({
    required bool closeDrawerOnTap,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
  }) {
    return Column(
      children: [
        Expanded(
          child: _buildNavigationList(
            closeDrawerOnTap: closeDrawerOnTap,
            padding: padding,
          ),
        ),
        const Divider(height: 1),
        _AdminIdentityPanel(
          name: widget.store.userDisplayName,
          email: widget.store.userEmail,
          imageUrl: widget.store.userProfileImageUrl,
          onTap: () => _openAdminProfile(closeDrawerFirst: closeDrawerOnTap),
        ),
      ],
    );
  }

  Future<void> _openAdminProfile({required bool closeDrawerFirst}) async {
    Future<void> presentProfile() async {
      if (!mounted) {
        return;
      }

      final isCompact = MediaQuery.of(context).size.width < 700;

      if (isCompact) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: _AdminProfilePanel(
              store: widget.store,
              onLogout: widget.onLogout,
            ),
          ),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _AdminProfilePanel(
              store: widget.store,
              onLogout: widget.onLogout,
            ),
          ),
        ),
      );
    }

    if (closeDrawerFirst) {
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        presentProfile();
      });
      return;
    }

    await presentProfile();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        _maybeShowAlerts();

        final isMobile = MediaQuery.of(context).size.width < 700;
        final useRail = !isMobile && _navItems.length > 5;

        final content = IndexedStack(
          index: _selectedIndex,
          children: [
            EntranceMotion(
              active: _selectedIndex == 0,
              child: AdminDashboardPage(
                store: widget.store,
                active: _selectedIndex == 0,
              ),
            ),
            EntranceMotion(
              active: _selectedIndex == 1,
              child: ProductManagementPage(store: widget.store),
            ),
            EntranceMotion(
              active: _selectedIndex == 2,
              child: InventoryPage(store: widget.store),
            ),
            EntranceMotion(
              active: _selectedIndex == 3,
              child: OrderManagementPage(store: widget.store),
            ),
            EntranceMotion(
              active: _selectedIndex == 4,
              child: SalesReportPage(store: widget.store),
            ),
            EntranceMotion(
              active: _selectedIndex == 5,
              child: CouponManagementPage(store: widget.store),
            ),
            EntranceMotion(
              active: _selectedIndex == 6,
              child: SupportInboxPage(store: widget.store),
            ),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              ThemeModeMenu(
                themeMode: widget.themeMode,
                themeStyle: widget.themeStyle,
                onChanged: widget.onThemeModeChanged,
                onStyleChanged: widget.onThemeStyleChanged,
                onTriggerOrigin: widget.onThemeTriggerOrigin,
              ),
              IconButton(
                onPressed: _isManualRefreshing ? null : _refreshCurrentData,
                tooltip: 'Refresh',
                icon: _isManualRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
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
                  child: SafeArea(
                    child: _buildNavigationPanel(closeDrawerOnTap: true),
                  ),
                )
              : null,
          body: useRail
              ? Row(
                  children: [
                    Container(
                      width: 248,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          right: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        right: false,
                        child: _buildNavigationPanel(closeDrawerOnTap: false),
                      ),
                    ),
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

class _AdminIdentityPanel extends StatefulWidget {
  const _AdminIdentityPanel({
    required this.name,
    required this.email,
    required this.imageUrl,
    required this.onTap,
  });

  final String name;
  final String email;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  State<_AdminIdentityPanel> createState() => _AdminIdentityPanelState();
}

class _AdminIdentityPanelState extends State<_AdminIdentityPanel> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trimmedName = widget.name.trim();
    final email = widget.email.trim();
    final displayName = trimmedName.isNotEmpty ? trimmedName : email;
    final initialsSource = displayName.isNotEmpty ? displayName : 'Admin';
    final parts = initialsSource
        .split(' ')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final initials = parts.isNotEmpty
        ? parts.take(2).map((value) => value[0].toUpperCase()).join()
        : 'A';
    final showEmail = email.isNotEmpty && displayName != email;
    final backgroundColor = _pressed
        ? scheme.primary.withValues(alpha: 0.12)
        : _hovered
        ? scheme.primary.withValues(alpha: 0.08)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final borderColor = _hovered
        ? scheme.outlineVariant.withValues(alpha: 0.75)
        : scheme.outlineVariant.withValues(alpha: 0.4);
    final avatarShellColor = _hovered
        ? scheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;
    final nameColor = _hovered ? scheme.onSurface : scheme.onSurface;
    final emailColor = _hovered ? scheme.onSurface : scheme.onSurfaceVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            onHighlightChanged: (value) {
              if (mounted) {
                setState(() => _pressed = value);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOutCubic,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: avatarShellColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: _AdminDrawerAvatar(
                      imageUrl: widget.imageUrl,
                      initials: initials,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOutCubic,
                          style:
                              (theme.textTheme.titleSmall ?? const TextStyle())
                                  .copyWith(
                                    color: nameColor,
                                    fontWeight: _hovered
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                          child: Text(
                            displayName.isNotEmpty ? displayName : 'Admin',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showEmail) ...[
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOutCubic,
                            style:
                                (theme.textTheme.bodySmall ?? const TextStyle())
                                    .copyWith(color: emailColor),
                            child: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _hovered
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminDrawerAvatar extends StatelessWidget {
  const _AdminDrawerAvatar({
    required this.imageUrl,
    required this.initials,
    this.size = 52,
  });

  final String? imageUrl;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.95),
            scheme.secondaryContainer.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _AdminDrawerAvatarFallback(initials: initials);
                },
              )
            : _AdminDrawerAvatarFallback(initials: initials),
      ),
    );
  }
}

class _AdminDrawerAvatarFallback extends StatelessWidget {
  const _AdminDrawerAvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _AdminProfilePanel extends StatefulWidget {
  const _AdminProfilePanel({
    required this.store,
    required this.onLogout,
  });

  final GroceryStoreState store;
  final VoidCallback onLogout;

  @override
  State<_AdminProfilePanel> createState() => _AdminProfilePanelState();
}

class _AdminProfilePanelState extends State<_AdminProfilePanel> {
  bool _uploadingProfileImage = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickProfileImage() async {
    final file = await pickProfileImageWithOptions(
      context,
      picker: _picker,
      title: 'Update admin profile photo',
    );
    if (file == null || !mounted) {
      return;
    }

    setState(() {
      _uploadingProfileImage = true;
    });

    try {
      final uploadedUrl = await widget.store.uploadProfileImage(file);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uploadedUrl != null && uploadedUrl.isNotEmpty
                ? 'Admin profile photo updated.'
                : 'Admin profile photo upload failed.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingProfileImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final trimmedName = widget.store.userDisplayName.trim();
        final trimmedEmail = widget.store.userEmail.trim();
        final displayName = trimmedName.isNotEmpty ? trimmedName : trimmedEmail;
        final initialsSource = displayName.isNotEmpty ? displayName : 'Admin';
        final initials = initialsSource
            .split(' ')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();
        final openTicketCount = widget.store.supportTickets
            .where((ticket) => ticket.status != 'closed')
            .length;
        final statCards = [
          _AdminProfileStat(
            label: 'Products',
            value: '${widget.store.allProducts.length}',
            icon: Icons.shopping_bag_outlined,
          ),
          _AdminProfileStat(
            label: 'Orders',
            value: '${widget.store.allOrders.length}',
            icon: Icons.receipt_long_outlined,
          ),
          _AdminProfileStat(
            label: 'Open Tickets',
            value: '$openTicketCount',
            icon: Icons.support_agent_outlined,
          ),
          _AdminProfileStat(
            label: 'Revenue',
            value: '\$${widget.store.revenueTotal.toStringAsFixed(2)}',
            icon: Icons.payments_outlined,
          ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdminEditableAvatar(
                    imageUrl: widget.store.userProfileImageUrl,
                    initials: initials.isNotEmpty ? initials : 'A',
                    uploading: _uploadingProfileImage,
                    onTap: _pickProfileImage,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin profile',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          displayName.isNotEmpty
                              ? displayName
                              : 'Administrator',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (trimmedEmail.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            trimmedEmail,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Tap the avatar to take a new photo or choose one from this device.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Administrator',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Signed in to manage the Fresh Mart catalog, orders, support tickets, and store operations.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                ),
                itemCount: statCards.length,
                itemBuilder: (context, index) {
                  final stat = statCards[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.36),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(stat.icon, color: scheme.primary),
                        const SizedBox(height: 10),
                        Text(
                          stat.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stat.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onLogout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminProfileStat {
  const _AdminProfileStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _AdminEditableAvatar extends StatelessWidget {
  const _AdminEditableAvatar({
    required this.imageUrl,
    required this.initials,
    required this.uploading,
    required this.onTap,
  });

  final String? imageUrl;
  final String initials;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Upload admin profile image',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: uploading ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _AdminDrawerAvatar(
                imageUrl: imageUrl,
                initials: initials,
                size: 78,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: uploading
                      ? Padding(
                          padding: const EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        )
                      : Icon(
                          Icons.photo_camera_outlined,
                          size: 16,
                          color: scheme.primary,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
