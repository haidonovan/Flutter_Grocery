// lib/client/payment_screen.dart
// Drop this file into: lib/client/payment_screen.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/client/payway_service.dart';

/// Result returned to the caller (checkout page) when payment finishes.
class PaymentResult {
  final bool success;
  final String? tranId;
  final String? message;
  const PaymentResult({required this.success, this.tranId, this.message});
}

/// Full-screen payment page shown after checkout places the order.
/// Displays the ABA Pay QR code and a "Open ABA Mobile" deeplink button.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.apiBaseUrl,
    required this.orderId,
    required this.amount,
    required this.paymentOption,
    this.currency = 'USD',
    this.firstname,
    this.lastname,
    this.email,
    this.phone,
  });

  final String apiBaseUrl;
  final String orderId;
  final double amount;
  final String paymentOption;
  final String currency;
  final String? firstname;
  final String? lastname;
  final String? email;
  final String? phone;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  PayWayPaymentResult? _result;
  bool _loading = true;
  String? _error;

  // QR expiry countdown (PayWay QR is valid ~3 minutes)
  static const _qrExpirySeconds = 180;
  int _secondsLeft = _qrExpirySeconds;
  Timer? _countdownTimer;

  // Polling timer — checks payment status every 5 seconds
  Timer? _pollTimer;
  bool _paid = false;

  late AnimationController _pulseController;
  late Animation<double>    _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync  : this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initPayment();
  }

  Future<void> _initPayment() async {
    setState(() { _loading = true; _error = null; });

    final result = await PayWayService.createPayment(
      baseUrl       : widget.apiBaseUrl,
      orderId       : widget.orderId,
      amount        : widget.amount,
      paymentOption : widget.paymentOption,
      currency      : widget.currency,
      firstname     : widget.firstname,
      lastname      : widget.lastname,
      email         : widget.email,
      phone         : widget.phone,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _result  = result;
        _loading = false;
      });
      _startCountdown();
      _startPolling(result.tranId!);
    } else {
      setState(() {
        _error   = result.errorMessage ?? 'Failed to create payment';
        _loading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft <= 0) {
        t.cancel();
        if (mounted && !_paid) {
          setState(() => _error = 'QR code expired. Tap "Refresh" to try again.');
        }
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _startPolling(String tranId) {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (t) async {
      if (!mounted || _paid) { t.cancel(); return; }

      final check = await PayWayService.checkTransaction(
        baseUrl: widget.apiBaseUrl,
        tranId: tranId,
      );
      if (!mounted) return;

      final paid = check['paid'] == true;
      final paymentStatus =
          (check['paymentStatus'] ??
                  (check['data'] as Map<String, dynamic>?)?['data']?['payment_status'])
              ?.toString()
              .toUpperCase();

      if (paid || paymentStatus == 'APPROVED') {
        t.cancel();
        setState(() => _paid = true);
        _countdownTimer?.cancel();
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.of(context).pop(
            PaymentResult(success: true, tranId: tranId, message: 'Payment confirmed'),
          );
        }
      }
    });
  }

  void _openAbaApp() async {
    final deeplink = _result?.abaDeeplink;
    if (deeplink == null) return;
    // Use url_launcher if available; otherwise show a copy dialog
    _showDeeplinkDialog(deeplink);
  }

  void _showDeeplinkDialog(String deeplink) {
    showDialog(
      context : context,
      builder : (_) => AlertDialog(
        title   : const Text('Open ABA Mobile'),
        content : const Text(
          'To pay, open ABA Mobile app on your phone and scan the QR code, '
          'or tap the button below to copy the deeplink.',
        ),
        actions : [
          TextButton(
            onPressed : () {
              Clipboard.setData(ClipboardData(text: deeplink));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deeplink copied!')),
              );
            },
            child: const Text('Copy deeplink'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child    : const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title      : const Text('Pay with ABA'),
        centerTitle: true,
        actions    : [
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child  : Chip(
                label: Text(
                  _formatTime(_secondsLeft),
                  style: TextStyle(
                    fontWeight : FontWeight.bold,
                    color      : _secondsLeft < 30
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ),
                ),
                avatar: Icon(
                  Icons.timer_outlined,
                  size : 16,
                  color: _secondsLeft < 30 ? scheme.error : null,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) return _buildLoading();
    if (_paid)    return _buildPaid(scheme);
    if (_error != null) return _buildError(scheme);
    return _buildPayment(scheme);
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Generating payment QR…'),
        ],
      ),
    );
  }

  Widget _buildPaid(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: scheme.primary, size: 80),
          const SizedBox(height: 16),
          Text(
            'Payment Confirmed!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color      : scheme.primary,
              fontWeight : FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Your order is being processed.'),
        ],
      ),
    );
  }

  Widget _buildError(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 60),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed : () {
                setState(() {
                  _error       = null;
                  _secondsLeft = _qrExpirySeconds;
                });
                _initPayment();
              },
              icon  : const Icon(Icons.refresh),
              label : const Text('Refresh'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed : () => Navigator.of(context).pop(
                const PaymentResult(success: false, message: 'Payment cancelled'),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayment(ColorScheme scheme) {
    final result = _result!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // ── Amount card ────────────────────────────────────────────────
          Card(
            color : scheme.primaryContainer,
            child : Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_outlined, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 10),
                  Text(
                    '\$${widget.amount.toStringAsFixed(2)} ${widget.currency}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color     : scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── QR image ───────────────────────────────────────────────────
          if (result.qrImageBytes != null)
            _buildQrImage(result, scheme)
          else if (result.qrString != null)
            _buildQrStringFallback(result.qrString!, scheme),

          const SizedBox(height: 24),

          // ── Instructions ───────────────────────────────────────────────
          _buildInstructions(scheme),
          const SizedBox(height: 24),

          // ── Open ABA button ────────────────────────────────────────────
          if (result.abaDeeplink != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed : _openAbaApp,
                icon      : const Icon(Icons.open_in_new),
                label     : const Text('Open ABA Mobile App'),
                style     : FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          const SizedBox(height: 12),

          // ── Cancel ─────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed : () => Navigator.of(context).pop(
                const PaymentResult(success: false, message: 'Payment cancelled'),
              ),
              child: const Text('Cancel payment'),
            ),
          ),
          const SizedBox(height: 16),

          // ── Polling status ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Waiting for payment…',
                style: TextStyle(color: scheme.outline, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrImage(PayWayPaymentResult result, ColorScheme scheme) {
    return ScaleTransition(
      scale: _pulseAnim,
      child: Container(
        padding     : const EdgeInsets.all(16),
        decoration  : BoxDecoration(
          color       : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow   : [
            BoxShadow(
              color      : scheme.shadow.withValues(alpha: 0.15),
              blurRadius : 20,
              offset     : const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Image.memory(
              Uint8List.fromList(result.qrImageBytes!),
              width  : 220,
              height : 220,
              fit    : BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize     : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://www.ababank.com/fileadmin/user_upload/aba-pay-logo.png',
                  height     : 24,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
                const SizedBox(width: 6),
                Text(
                  'ABA Pay',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color     : const Color(0xFF003087),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrStringFallback(String qrString, ColorScheme scheme) {
    return Container(
      padding    : const EdgeInsets.all(16),
      decoration : BoxDecoration(
        color       : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border      : Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_2, size: 64),
          const SizedBox(height: 8),
          const Text('QR Code String:'),
          const SizedBox(height: 8),
          SelectableText(
            qrString,
            style    : const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed : () {
              Clipboard.setData(ClipboardData(text: qrString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR string copied!')),
              );
            },
            icon : const Icon(Icons.copy, size: 16),
            label: const Text('Copy QR string'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions(ColorScheme scheme) {
    return Container(
      padding    : const EdgeInsets.all(16),
      decoration : BoxDecoration(
        color       : scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'How to pay:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          _Step(n: '1', text: 'Open your ABA Mobile app'),
          _Step(n: '2', text: 'Tap "Scan QR" on the home screen'),
          _Step(n: '3', text: 'Scan the QR code above'),
          _Step(n: '4', text: 'Confirm the payment in ABA Mobile'),
          _Step(n: '5', text: 'This screen will update automatically'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius          : 10,
            backgroundColor : scheme.secondary,
            child           : Text(
              n,
              style: TextStyle(fontSize: 10, color: scheme.onSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
