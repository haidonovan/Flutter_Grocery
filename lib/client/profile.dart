import 'package:flutter/material.dart';

import 'models.dart';
import '../widgets/skeleton.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.userEmail,
    required this.totalOrders,
    required this.onLogout,
    required this.onSendSupport,
    required this.activeCoupons,
    required this.isLoading,
  });

  final String userEmail;
  final int totalOrders;
  final VoidCallback onLogout;
  final Future<void> Function(String message) onSendSupport;
  final List<Coupon> activeCoupons;
  final bool isLoading;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supportController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _supportController.dispose();
    super.dispose();
  }

  Future<void> _submitSupport() async {
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
      await widget.onSendSupport(_supportController.text.trim());
      if (!mounted) {
        return;
      }
      _supportController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support message sent.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonBox(height: 80),
          SizedBox(height: 12),
          SkeletonBox(height: 60),
          SizedBox(height: 12),
          SkeletonBox(height: 60),
          SizedBox(height: 12),
          SkeletonBox(height: 140),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
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
                    Text(widget.userEmail),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Total orders'),
            trailing: Text('${widget.totalOrders}'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('Delivery preferences'),
            subtitle: const Text('Standard delivery - 2 to 3 days'),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.activeCoupons.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your coupons',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...widget.activeCoupons.map(
                    (coupon) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${coupon.code} • ${coupon.type == 'percent' ? '${coupon.value.toStringAsFixed(0)}%' : '\$${coupon.value.toStringAsFixed(2)}'}'
                        '${coupon.endsAt == null ? '' : ' • ends ${coupon.endsAt!.toLocal().toString().split(' ').first}'}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
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
                  controller: _supportController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Describe your issue',
                    border: OutlineInputBorder(),
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
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}
