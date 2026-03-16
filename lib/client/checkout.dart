import 'package:flutter/material.dart';

class CheckoutRequest {
  const CheckoutRequest({
    required this.shippingAddress,
    required this.paymentMethod,
    required this.couponCode,
  });

  final String shippingAddress;
  final String paymentMethod;
  final String? couponCode;
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.totalAmount,
    required this.itemCount,
  });

  final double totalAmount;
  final int itemCount;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _couponController = TextEditingController();
  String _paymentMethod = 'Cash on delivery';

  @override
  void dispose() {
    _addressController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  void _placeOrder() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(
        CheckoutRequest(
          shippingAddress: _addressController.text.trim(),
          paymentMethod: _paymentMethod,
          couponCode: _couponController.text.trim().isEmpty
              ? null
              : _couponController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
                    Text(
                      'Order summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Items'),
                        const Spacer(),
                        Text('${widget.itemCount}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Total'),
                        const Spacer(),
                        Text(
                          '\$${widget.totalAmount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delivery details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Shipping address',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 8) {
                  return 'Enter a full address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Coupon code', style: Theme.of(context).textTheme.titleMedium),
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
                      'Have a promo code from your coupon wallet or a campaign? Enter it below and the backend will validate the discount when you place the order.',
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
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment method',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Select method',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Cash on delivery',
                  child: Text('Cash on delivery'),
                ),
                DropdownMenuItem(
                  value: 'Credit card',
                  child: Text('Credit card'),
                ),
                DropdownMenuItem(
                  value: 'Bank transfer',
                  child: Text('Bank transfer'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _paymentMethod = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _placeOrder,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Place order securely'),
            ),
          ],
        ),
      ),
    );
  }
}
