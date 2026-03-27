// lib/client/checkout.dart
// Replace your existing lib/client/checkout.dart with this file.

import 'package:flutter/material.dart';
import 'package:flutter_app/client/payment_screen.dart';

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
    required this.apiBaseUrl,
    required this.totalAmount,
    required this.itemCount,
    // Pass orderId after your backend creates the order,
    // or pass it later when navigating to PaymentScreen.
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
  final _formKey          = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _couponController  = TextEditingController();

  String _paymentMethod = 'Cash on delivery';
  bool   _placingOrder  = false;

  // ── Payment method options ─────────────────────────────────────────────────
  static const _paymentOptions = [
    _PaymentOption(
      value  : 'Cash on delivery',
      label  : 'Cash on Delivery',
      icon   : Icons.money,
    ),
    _PaymentOption(
      value  : 'ABA Pay',
      label  : 'ABA Pay (QR)',
      icon   : Icons.qr_code_2,
      badge  : 'Recommended',
    ),
    _PaymentOption(
      value  : 'Credit card',
      label  : 'Credit / Debit Card',
      icon   : Icons.credit_card,
    ),
    _PaymentOption(
      value  : 'Bank transfer',
      label  : 'Bank Transfer',
      icon   : Icons.account_balance,
    ),
  ];

  @override
  void dispose() {
    _addressController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  // ── Place order handler ────────────────────────────────────────────────────
  Future<void> _placeOrder() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _placingOrder = true);

    final request = CheckoutRequest(
      shippingAddress: _addressController.text.trim(),
      paymentMethod  : _paymentMethod,
      couponCode     : _couponController.text.trim().isEmpty
          ? null
          : _couponController.text.trim(),
    );

    // ── ABA Pay: navigate to payment screen ──────────────────────────────────
    if (_paymentMethod == 'ABA Pay') {
      setState(() => _placingOrder = false);
      await _handleAbaPayment(request);
      return;
    }

    // ── Other methods: return to caller as before ────────────────────────────
    setState(() => _placingOrder = false);
    if (mounted) Navigator.of(context).pop(request);
  }

  Future<void> _handleAbaPayment(CheckoutRequest request) async {
    // If you have an orderId from the parent, use it; otherwise generate one.
    final orderId = widget.orderId ?? DateTime.now().millisecondsSinceEpoch.toString();

    final paymentResult = await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          apiBaseUrl   : widget.apiBaseUrl,
          orderId       : orderId,
          amount        : widget.totalAmount,
          paymentOption : 'abapay',    // ABA Pay QR
          currency      : 'USD',
          firstname     : widget.userFirstname,
          lastname      : widget.userLastname,
          email         : widget.userEmail,
          phone         : widget.userPhone,
        ),
      ),
    );

    if (!mounted) return;

    if (paymentResult?.success == true) {
      // Payment confirmed — return to cart/home with success
      Navigator.of(context).pop(
        CheckoutRequest(
          shippingAddress: request.shippingAddress,
          paymentMethod  : 'ABA Pay (${paymentResult!.tranId})',
          couponCode     : request.couponCode,
        ),
      );
    } else if (paymentResult?.success == false &&
        paymentResult?.message != 'Payment cancelled') {
      // Payment failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(paymentResult?.message ?? 'Payment was not completed.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
    // If cancelled, just stay on checkout
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key  : _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Order summary ─────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order summary', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _SummaryRow(label: 'Items',
                        value: '${widget.itemCount}'),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label      : 'Total',
                      value      : '\$${widget.totalAmount.toStringAsFixed(2)}',
                      valueStyle : theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Delivery details ──────────────────────────────────────────
            Text('Delivery details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              maxLines  : 3,
              decoration: const InputDecoration(
                labelText: 'Shipping address',
                border   : OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 8) {
                  return 'Enter a full address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Coupon ────────────────────────────────────────────────────
            Text('Coupon code', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              padding   : const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient    : LinearGradient(
                  begin  : Alignment.topLeft,
                  end    : Alignment.bottomRight,
                  colors : [
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
                    padding   : const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color       : scheme.surface.withValues(alpha: 0.4),
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
                      'Have a promo code from your coupon wallet or a campaign? '
                      'Enter it below and the backend will validate the discount '
                      'when you place the order.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color : scheme.onPrimaryContainer,
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
                labelText  : 'Enter coupon (optional)',
                helperText :
                    'Copy a code from Profile > Coupon wallet and paste it here. '
                    'Each account can redeem a coupon only once.',
                filled     : true,
                fillColor  : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                border     : const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Payment method ────────────────────────────────────────────
            Text('Payment method', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._paymentOptions.map((option) => _PaymentTile(
              option    : option,
              selected  : _paymentMethod == option.value,
              onTap     : () => setState(() => _paymentMethod = option.value),
            )),
            const SizedBox(height: 24),

            // ── ABA Pay info banner ───────────────────────────────────────
            if (_paymentMethod == 'ABA Pay')
              Container(
                margin    : const EdgeInsets.only(bottom: 16),
                padding   : const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color       : const Color(0xFF003087).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border      : Border.all(
                    color: const Color(0xFF003087).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF003087)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You\'ll be shown a QR code to scan with your ABA Mobile app. '
                        'Payment is confirmed instantly.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF003087),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Place order button ─────────────────────────────────────────
            FilledButton.icon(
              onPressed: _placingOrder ? null : _placeOrder,
              icon     : _placingOrder
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
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

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _PaymentOption {
  const _PaymentOption({
    required this.value,
    required this.label,
    required this.icon,
    this.badge,
  });
  final String  value;
  final String  label;
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration   : const Duration(milliseconds: 200),
        margin     : const EdgeInsets.only(bottom: 8),
        padding    : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration : BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border      : Border.all(
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
                  color     : selected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
            if (option.badge != null)
              Container(
                padding   : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color       : scheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  option.badge!,
                  style: TextStyle(
                    fontSize   : 10,
                    color      : scheme.onPrimary,
                    fontWeight : FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Radio<String>(
              value    : option.value,
              groupValue: selected ? option.value : '',
              onChanged: (_) => onTap(),
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
        Text(label),
        const Spacer(),
        Text(value, style: valueStyle),
      ],
    );
  }
}


// import 'package:flutter/material.dart';

// class CheckoutRequest {
//   const CheckoutRequest({
//     required this.shippingAddress,
//     required this.paymentMethod,
//     required this.couponCode,
//   });

//   final String shippingAddress;
//   final String paymentMethod;
//   final String? couponCode;
// }

// class CheckoutPage extends StatefulWidget {
//   const CheckoutPage({
//     super.key,
//     required this.totalAmount,
//     required this.itemCount,
//   });

//   final double totalAmount;
//   final int itemCount;

//   @override
//   State<CheckoutPage> createState() => _CheckoutPageState();
// }

// class _CheckoutPageState extends State<CheckoutPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _addressController = TextEditingController();
//   final _couponController = TextEditingController();
//   String _paymentMethod = 'Cash on delivery';

//   @override
//   void dispose() {
//     _addressController.dispose();
//     _couponController.dispose();
//     super.dispose();
//   }

//   void _placeOrder() {
//     if (_formKey.currentState?.validate() ?? false) {
//       Navigator.of(context).pop(
//         CheckoutRequest(
//           shippingAddress: _addressController.text.trim(),
//           paymentMethod: _paymentMethod,
//           couponCode: _couponController.text.trim().isEmpty
//               ? null
//               : _couponController.text.trim(),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final scheme = theme.colorScheme;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Checkout')),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           padding: const EdgeInsets.all(16),
//           children: [
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Order summary',
//                       style: Theme.of(context).textTheme.titleMedium,
//                     ),
//                     const SizedBox(height: 12),
//                     Row(
//                       children: [
//                         const Text('Items'),
//                         const Spacer(),
//                         Text('${widget.itemCount}'),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         const Text('Total'),
//                         const Spacer(),
//                         Text(
//                           '\$${widget.totalAmount.toStringAsFixed(2)}',
//                           style: Theme.of(context).textTheme.titleMedium,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Delivery details',
//               style: Theme.of(context).textTheme.titleMedium,
//             ),
//             const SizedBox(height: 8),
//             TextFormField(
//               controller: _addressController,
//               maxLines: 3,
//               decoration: const InputDecoration(
//                 labelText: 'Shipping address',
//                 border: OutlineInputBorder(),
//               ),
//               validator: (value) {
//                 if ((value ?? '').trim().length < 8) {
//                   return 'Enter a full address';
//                 }
//                 return null;
//               },
//             ),
//             const SizedBox(height: 16),
//             Text('Coupon code', style: Theme.of(context).textTheme.titleMedium),
//             const SizedBox(height: 8),
//             Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(18),
//                 gradient: LinearGradient(
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                   colors: [
//                     scheme.primaryContainer.withValues(alpha: 0.7),
//                     scheme.secondaryContainer.withValues(alpha: 0.55),
//                   ],
//                 ),
//                 border: Border.all(
//                   color: scheme.outlineVariant.withValues(alpha: 0.5),
//                 ),
//               ),
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                       color: scheme.surface.withValues(alpha: 0.4),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Icon(
//                       Icons.local_offer_outlined,
//                       color: scheme.onPrimaryContainer,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Text(
//                       'Have a promo code from your coupon wallet or a campaign? Enter it below and the backend will validate the discount when you place the order.',
//                       style: theme.textTheme.bodyMedium?.copyWith(
//                         color: scheme.onPrimaryContainer,
//                         height: 1.35,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 10),
//             TextFormField(
//               controller: _couponController,
//               decoration: InputDecoration(
//                 labelText: 'Enter coupon (optional)',
//                 helperText:
//                     'Copy a code from Profile > Coupon wallet and paste it here. Each account can redeem a coupon only once.',
//                 filled: true,
//                 fillColor: scheme.surfaceContainerHighest.withValues(
//                   alpha: 0.55,
//                 ),
//                 border: const OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Payment method',
//               style: Theme.of(context).textTheme.titleMedium,
//             ),
//             const SizedBox(height: 8),
//             DropdownButtonFormField<String>(
//               initialValue: _paymentMethod,
//               decoration: const InputDecoration(
//                 labelText: 'Select method',
//                 border: OutlineInputBorder(),
//               ),
//               items: const [
//                 DropdownMenuItem(
//                   value: 'Cash on delivery',
//                   child: Text('Cash on delivery'),
//                 ),
//                 DropdownMenuItem(
//                   value: 'Credit card',
//                   child: Text('Credit card'),
//                 ),
//                 DropdownMenuItem(
//                   value: 'Bank transfer',
//                   child: Text('Bank transfer'),
//                 ),
//               ],
//               onChanged: (value) {
//                 if (value != null) {
//                   setState(() {
//                     _paymentMethod = value;
//                   });
//                 }
//               },
//             ),
//             const SizedBox(height: 24),
//             FilledButton.icon(
//               onPressed: _placeOrder,
//               icon: const Icon(Icons.lock_outline),
//               label: const Text('Place order securely'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
