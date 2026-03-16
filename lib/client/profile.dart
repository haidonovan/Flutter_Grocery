import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/coupon_banner.dart';
import '../widgets/entrance_motion.dart';
import 'models.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.userEmail,
    required this.totalOrders,
    required this.onLogout,
    required this.onSendSupport,
    required this.onReplySupport,
    required this.onCloseSupport,
    required this.activeCoupons,
    required this.supportTickets,
    required this.isLoading,
    this.motionEpoch = 0,
  });

  final String userEmail;
  final int totalOrders;
  final VoidCallback onLogout;
  final Future<void> Function(String subject, String message) onSendSupport;
  final Future<void> Function(int ticketId, String message) onReplySupport;
  final Future<void> Function(int ticketId) onCloseSupport;
  final List<Coupon> activeCoupons;
  final List<SupportTicket> supportTickets;
  final bool isLoading;
  final int motionEpoch;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _subjectController = TextEditingController();
  final _supportController = TextEditingController();
  bool _sending = false;
  final Map<int, TextEditingController> _replyControllers = {};

  @override
  void dispose() {
    _subjectController.dispose();
    _supportController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _replyControllerFor(int ticketId) {
    return _replyControllers.putIfAbsent(ticketId, TextEditingController.new);
  }

  Future<void> _submitSupport() async {
    if (_subjectController.text.trim().length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a subject.')));
      return;
    }
    if (_supportController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a longer message.')),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.onSendSupport(
        _subjectController.text.trim(),
        _supportController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _subjectController.clear();
      _supportController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Support message sent.')));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _showCoupons() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CouponWalletSheet(coupons: widget.activeCoupons),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final walletGradient = isDark
        ? [
            scheme.surfaceContainerHighest,
            scheme.primaryContainer.withValues(alpha: 0.85),
            scheme.secondaryContainer.withValues(alpha: 0.72),
          ]
        : [
            scheme.primaryContainer.withValues(alpha: 0.95),
            scheme.secondaryContainer.withValues(alpha: 0.92),
            scheme.tertiaryContainer.withValues(alpha: 0.82),
          ];
    final walletForeground = isDark
        ? scheme.onSurface
        : scheme.onPrimaryContainer;
    final supportGradient = isDark
        ? [
            scheme.surfaceContainerHighest,
            scheme.surfaceContainer,
            scheme.primaryContainer.withValues(alpha: 0.38),
          ]
        : [
            scheme.surfaceContainerLow,
            scheme.surface,
            scheme.secondaryContainer.withValues(alpha: 0.45),
          ];
    final supportForeground = scheme.onSurface;

    Color statusBackground(String status) {
      switch (status) {
        case 'closed':
          return isDark
              ? Colors.green.withValues(alpha: 0.72)
              : Colors.green.withValues(alpha: 0.18);
        case 'answered':
          return isDark
              ? scheme.primary.withValues(alpha: 0.72)
              : scheme.primaryContainer.withValues(alpha: 0.9);
        default:
          return isDark
              ? scheme.tertiary.withValues(alpha: 0.72)
              : scheme.tertiaryContainer.withValues(alpha: 0.95);
      }
    }

    Color statusForeground(String status) {
      switch (status) {
        case 'closed':
          return isDark ? Colors.white : Colors.green.shade900;
        case 'answered':
          return isDark ? Colors.white : scheme.onPrimaryContainer;
        default:
          return isDark ? Colors.white : scheme.onTertiaryContainer;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EntranceMotion(
          delay: const Duration(milliseconds: 60),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.teal.withValues(alpha: 0.15),
                  Colors.teal.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.userEmail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: widget.onLogout,
                  tooltip: 'Logout',
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        EntranceMotion(
          delay: const Duration(milliseconds: 120),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Total orders'),
              trailing: Text('${widget.totalOrders}'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        EntranceMotion(
          delay: const Duration(milliseconds: 180),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Delivery preferences'),
              subtitle: const Text('Standard delivery - 2 to 3 days'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        EntranceMotion(
          key: ValueKey('coupon-wallet-${widget.motionEpoch}'),
          delay: const Duration(milliseconds: 240),
          child: RepaintBoundary(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showCoupons,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: walletGradient,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: walletForeground.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.confirmation_number_outlined,
                                color: walletForeground,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Coupon wallet',
                                    style: Theme.of(context).textTheme.titleLarge
                                        ?.copyWith(
                                          color: walletForeground,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.activeCoupons.isNotEmpty
                                        ? 'Tap to view, copy, and use your coupons'
                                        : 'No coupons yet. New offers will appear here.',
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(
                                          color: walletForeground.withValues(alpha: 0.82),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 18,
                              color: walletForeground,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (widget.activeCoupons.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.activeCoupons.take(3).map((coupon) {
                              final valueLabel = coupon.type == 'percent'
                                  ? '${coupon.value.toStringAsFixed(0)}% OFF'
                                  : '\$${coupon.value.toStringAsFixed(2)} OFF';
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: walletForeground.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: walletForeground.withValues(alpha: 0.16),
                                  ),
                                ),
                                child: Text(
                                  '${coupon.code}  $valueLabel',
                                  style: TextStyle(
                                    color: walletForeground,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: walletForeground.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: walletForeground.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              'When the store publishes a promo or assigns a coupon to your account, you will see it here.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: walletForeground.withValues(alpha: 0.86),
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              widget.activeCoupons.isNotEmpty
                                  ? '${widget.activeCoupons.length} available'
                                  : 'Waiting for offers',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: walletForeground.withValues(alpha: 0.82),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.activeCoupons.isNotEmpty
                                  ? 'Open wallet'
                                  : 'Check offers',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: walletForeground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.supportTickets.isNotEmpty)
          EntranceMotion(
            delay: const Duration(milliseconds: 320),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: supportGradient,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your support tickets',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: supportForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track replies and ticket status from the support team.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: supportForeground.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (var index = 0; index < widget.supportTickets.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: EntranceMotion(
                          delay: Duration(milliseconds: 360 + (index * 70)),
                          child: _SupportTicketCard(
                            ticket: widget.supportTickets[index],
                            isDark: isDark,
                            scheme: scheme,
                            supportForeground: supportForeground,
                            statusBackground: statusBackground,
                            statusForeground: statusForeground,
                            replyController: _replyControllerFor(
                              widget.supportTickets[index].id,
                            ),
                            onReplySupport: widget.onReplySupport,
                            onCloseSupport: widget.onCloseSupport,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (widget.supportTickets.isNotEmpty) const SizedBox(height: 12),
        EntranceMotion(
          delay: const Duration(milliseconds: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support team',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _supportController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Describe your issue',
                      helperText:
                          'Only signed-in users can create tickets. Replies will appear above in your ticket history.',
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _sending ? null : _submitSupport,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.support_agent),
                    label: Text(_sending ? 'Sending...' : 'Contact support'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportTicketCard extends StatelessWidget {
  const _SupportTicketCard({
    required this.ticket,
    required this.isDark,
    required this.scheme,
    required this.supportForeground,
    required this.statusBackground,
    required this.statusForeground,
    required this.replyController,
    required this.onReplySupport,
    required this.onCloseSupport,
  });

  final SupportTicket ticket;
  final bool isDark;
  final ColorScheme scheme;
  final Color supportForeground;
  final Color Function(String status) statusBackground;
  final Color Function(String status) statusForeground;
  final TextEditingController replyController;
  final Future<void> Function(int ticketId, String message) onReplySupport;
  final Future<void> Function(int ticketId) onCloseSupport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.12 : 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(
                    alpha: isDark ? 0.3 : 0.8,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.support_agent,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: supportForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground(ticket.status),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        ticket.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: statusForeground(ticket.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...ticket.messages.map((message) {
            final isAdminMessage = message.userRole == 'admin';
            final bubbleColor = isAdminMessage
                ? scheme.secondaryContainer.withValues(alpha: isDark ? 0.28 : 0.72)
                : scheme.primaryContainer.withValues(alpha: isDark ? 0.22 : 0.55);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: isAdminMessage ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAdminMessage ? 'Support team' : 'You',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: supportForeground.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: supportForeground,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (ticket.status != 'closed') ...[
            TextField(
              controller: replyController,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reply to this ticket',
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final text = replyController.text.trim();
                    if (text.length < 3) {
                      return;
                    }
                    await onReplySupport(ticket.id, text);
                    replyController.clear();
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send reply'),
                ),
                TextButton(
                  onPressed: () => onCloseSupport(ticket.id),
                  child: const Text('Close ticket'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CouponWalletSheet extends StatelessWidget {
  const _CouponWalletSheet({required this.coupons});

  final List<Coupon> coupons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: EntranceMotion(
                  delay: const Duration(milliseconds: 60),
                  duration: const Duration(milliseconds: 420),
                  beginOffset: const Offset(0, 0.035),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Coupon wallet',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${coupons.length} ready to use',
                              style: theme.textTheme.bodyMedium,
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
                ),
              ),
              if (coupons.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: coupons.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final coupon = coupons[index];
                      return EntranceMotion(
                        delay: Duration(milliseconds: 100 + (index * 60)),
                        duration: const Duration(milliseconds: 420),
                        beginOffset: const Offset(0, 0.03),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CouponBanner(coupon: coupon),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: coupon.code),
                                      );
                                      if (!context.mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Coupon ${coupon.code} copied.'),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded),
                                    label: const Text('Copy code'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: EntranceMotion(
                      delay: const Duration(milliseconds: 120),
                      duration: const Duration(milliseconds: 420),
                      beginOffset: const Offset(0, 0.035),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_offer_outlined,
                              size: 36,
                              color: scheme.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No coupons yet',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'When the store publishes an offer or assigns one to your account, it will appear here and you can copy the code into checkout.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
