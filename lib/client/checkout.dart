import 'package:flutter/material.dart';

class CheckoutRequest {
  const CheckoutRequest({
    required this.shippingAddress,
    required this.paymentMethod,
  });

  final String shippingAddress;
  final String paymentMethod;
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
  String _paymentMethod = 'Cash on delivery';

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _placeOrder() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(
        CheckoutRequest(
          shippingAddress: _addressController.text.trim(),
          paymentMethod: _paymentMethod,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Order summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
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
                        Text('\$${widget.totalAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment method',
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
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _placeOrder,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Place order'),
            ),
          ],
        ),
      ),
    );
  }
}
