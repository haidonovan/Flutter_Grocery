import 'package:flutter/material.dart';

import '../widgets/app_page_route.dart';
import '../widgets/location_picker_page.dart';
import 'payment_screen.dart';

class CheckoutRequest {
  const CheckoutRequest({
    required this.shippingAddress,
    required this.paymentMethod,
    required this.couponCode,
    this.shippingLatitude,
    this.shippingLongitude,
    this.shippingPlaceLabel,
  });

  final String shippingAddress;
  final String paymentMethod;
  final String? couponCode;
  final double? shippingLatitude;
  final double? shippingLongitude;
  final String? shippingPlaceLabel;

  bool get hasShippingLocation =>
      shippingLatitude != null && shippingLongitude != null;
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.apiBaseUrl,
    required this.totalAmount,
    required this.itemCount,
    this.orderId,
    this.userFirstname,
    this.userLastname,
    this.userEmail,
    this.userPhone,
  });

  final String apiBaseUrl;
  final double totalAmount;
  final int itemCount;
  final String? orderId;
  final String? userFirstname;
  final String? userLastname;
  final String? userEmail;
  final String? userPhone;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _couponController = TextEditingController();

  String _paymentMethod = 'Cash on delivery';
  bool _placingOrder = false;
  SelectedLocation? _selectedLocation;

  static const _paymentOptions = [
    _PaymentOption(
      value: 'Cash on delivery',
      label: 'Cash on Delivery',
      icon: Icons.money,
    ),
    _PaymentOption(
      value: 'ABA Pay',
      label: 'ABA Pay (QR)',
      icon: Icons.qr_code_2,
      badge: 'Recommended',
    ),
    _PaymentOption(
      value: 'Credit card',
      label: 'Credit / Debit Card',
      icon: Icons.credit_card,
    ),
    _PaymentOption(
      value: 'Bank transfer',
      label: 'Bank Transfer',
      icon: Icons.account_balance,
    ),
  ];

  @override
  void dispose() {
    _addressController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final selection = await Navigator.of(context).push<SelectedLocation>(
      AppPageRoute<SelectedLocation>(
        builder: (_) => LocationPickerPage(
          initialAddress: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : _selectedLocation?.formattedAddress,
          initialLatitude: _selectedLocation?.latitude,
          initialLongitude: _selectedLocation?.longitude,
          initialPlaceLabel: _selectedLocation?.placeLabel,
        ),
      ),
    );

    if (!mounted || selection == null) {
      return;
    }

    setState(() {
      _selectedLocation = selection;
      _addressController.text = selection.formattedAddress;
      _addressController.selection = TextSelection.collapsed(
        offset: _addressController.text.length,
      );
    });
  }

  String _resolvedShippingAddress() {
    final typed = _addressController.text.trim();
    if (typed.isNotEmpty) {
      return typed;
    }
    return _selectedLocation?.formattedAddress ?? '';
  }

  Future<void> _placeOrder() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _placingOrder = true);

    final request = CheckoutRequest(
      shippingAddress: _resolvedShippingAddress(),
      paymentMethod: _paymentMethod,
      couponCode: _couponController.text.trim().isEmpty
          ? null
          : _couponController.text.trim(),
      shippingLatitude: _selectedLocation?.latitude,
      shippingLongitude: _selectedLocation?.longitude,
      shippingPlaceLabel: _selectedLocation?.label,
    );

    if (_paymentMethod == 'ABA Pay') {
      setState(() => _placingOrder = false);
      await _handleAbaPayment(request);
      return;
    }

    setState(() => _placingOrder = false);
    if (mounted) {
      Navigator.of(context).pop(request);
    }
  }

  Future<void> _handleAbaPayment(CheckoutRequest request) async {
    final orderId =
        widget.orderId ?? DateTime.now().millisecondsSinceEpoch.toString();

    final paymentResult = await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          apiBaseUrl: widget.apiBaseUrl,
          orderId: orderId,
          amount: widget.totalAmount,
          paymentOption: 'abapay',
          currency: 'USD',
          firstname: widget.userFirstname,
          lastname: widget.userLastname,
          email: widget.userEmail,
          phone: widget.userPhone,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (paymentResult?.success == true) {
      Navigator.of(context).pop(
        CheckoutRequest(
          shippingAddress: request.shippingAddress,
          paymentMethod: 'ABA Pay (${paymentResult!.tranId})',
          couponCode: request.couponCode,
          shippingLatitude: request.shippingLatitude,
          shippingLongitude: request.shippingLongitude,
          shippingPlaceLabel: request.shippingPlaceLabel,
        ),
      );
    } else if (paymentResult?.success == false &&
        paymentResult?.message != 'Payment cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentResult?.message ?? 'Payment was not completed.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedLocation = _selectedLocation;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order summary', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _SummaryRow(label: 'Items', value: '${widget.itemCount}'),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Total',
                      value: '\$${widget.totalAmount.toStringAsFixed(2)}',
                      valueStyle: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Delivery details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Shipping address',
                helperText:
                    'You can type the address yourself or pick the precise location below.',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length >= 8 || _selectedLocation != null) {
                  return null;
                }
                return 'Enter a full address or pick a map location';
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.location_searching_rounded,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Precise delivery location',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedLocation == null
                                  ? 'Optional, but helpful. Pin the exact spot so the admin can see it on the order.'
                                  : selectedLocation.formattedAddress,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                            if (selectedLocation != null) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _LocationChip(
                                    icon: Icons.place_outlined,
                                    label: selectedLocation.label,
                                  ),
                                  _LocationChip(
                                    icon: Icons.my_location_outlined,
                                    label:
                                        '${selectedLocation.latitude.toStringAsFixed(4)}, ${selectedLocation.longitude.toStringAsFixed(4)}',
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _pickLocation,
                        icon: Icon(
                          selectedLocation == null
                              ? Icons.map_outlined
                              : Icons.edit_location_alt_outlined,
                        ),
                        label: Text(
                          selectedLocation == null
                              ? 'Pick location'
                              : 'Update location',
                        ),
                      ),
                      if (selectedLocation != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedLocation = null;
                            });
                          },
                          icon: const Icon(Icons.clear_outlined),
                          label: const Text('Clear pin'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Coupon code', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer.withValues(alpha: 0.7),
                    scheme.secondaryContainer.withValues(alpha: 0.55),
                  ],
                ),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_offer_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Have a promo code from your coupon wallet or a campaign? Enter it below and the backend will validate it when you place the order.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _couponController,
              decoration: InputDecoration(
                labelText: 'Enter coupon (optional)',
                helperText:
                    'Copy a code from Profile > Coupon wallet and paste it here. Each account can redeem a coupon only once.',
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Payment method', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._paymentOptions.map(
              (option) => _PaymentTile(
                option: option,
                selected: _paymentMethod == option.value,
                onTap: () => setState(() => _paymentMethod = option.value),
              ),
            ),
            const SizedBox(height: 24),
            if (_paymentMethod == 'ABA Pay')
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF003087).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF003087).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF003087)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You will be shown a QR code to scan with your ABA Mobile app. Payment is confirmed instantly.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF003087),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton.icon(
              onPressed: _placingOrder ? null : _placeOrder,
              icon: _placingOrder
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _paymentMethod == 'ABA Pay'
                          ? Icons.qr_code_2
                          : Icons.lock_outline,
                    ),
              label: Text(
                _paymentMethod == 'ABA Pay'
                    ? 'Pay with ABA'
                    : 'Place order securely',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption {
  const _PaymentOption({
    required this.value,
    required this.label,
    required this.icon,
    this.badge,
  });

  final String value;
  final String label;
  final IconData icon;
  final String? badge;
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PaymentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.3)
              : scheme.surface,
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
            if (option.badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  option.badge!,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outline,
                  width: 2,
                ),
                color: selected ? scheme.primary : Colors.transparent,
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: scheme.onPrimary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
