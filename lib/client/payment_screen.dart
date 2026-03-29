import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'payway_service.dart';

class PaymentResult {
  const PaymentResult({
    required this.success,
    this.orderId,
    this.tranId,
    this.message,
  });

  final bool success;
  final String? orderId;
  final String? tranId;
  final String? message;
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.apiBaseUrl,
    required this.authToken,
    required this.amount,
    required this.shippingAddress,
    required this.lines,
    this.currency = 'USD',
    this.orderId,
    this.couponCode,
    this.shippingLatitude,
    this.shippingLongitude,
    this.shippingPlaceLabel,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.storeName = 'Grocery Store',
    this.onOrderCreated,
  });

  final String apiBaseUrl;
  final String authToken;
  final double amount;
  final String shippingAddress;
  final List<Map<String, dynamic>> lines;
  final String currency;
  final String? orderId;
  final String? couponCode;
  final double? shippingLatitude;
  final double? shippingLongitude;
  final String? shippingPlaceLabel;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String storeName;
  final VoidCallback? onOrderCreated;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const int _fallbackExpirySeconds = 180;
  static const Duration _pollInterval = Duration(seconds: 3);

  PayWayPaymentResult? _payment;
  String? _orderId;
  String? _error;
  bool _isLoading = true;
  bool _isPaid = false;
  bool _isCheckingStatus = false;
  bool _didNotifyOrderCreated = false;
  int _secondsLeft = _fallbackExpirySeconds;
  Timer? _countdownTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _orderId = widget.orderId;
    _createPayment();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createPayment() async {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await PayWayService.createPayment(
      baseUrl: widget.apiBaseUrl,
      authToken: widget.authToken,
      orderId: _orderId,
      amount: widget.amount,
      currency: widget.currency,
      shippingAddress: widget.shippingAddress,
      lines: widget.lines,
      couponCode: widget.couponCode,
      shippingLatitude: widget.shippingLatitude,
      shippingLongitude: widget.shippingLongitude,
      shippingPlaceLabel: widget.shippingPlaceLabel,
      firstName: widget.firstName,
      lastName: widget.lastName,
      email: widget.email,
      phone: widget.phone,
    );

    if (!mounted) {
      return;
    }

    if (!result.success || result.tranId == null) {
      setState(() {
        _isLoading = false;
        _error = result.errorMessage ?? 'Unable to generate KHQR payment.';
      });
      return;
    }

    final wasMissingOrderId = _orderId == null;
    _payment = result;
    _orderId = result.orderId ?? _orderId;
    _secondsLeft = result.secondsUntilExpiry > 0
        ? result.secondsUntilExpiry
        : _fallbackExpirySeconds;

    if (wasMissingOrderId && _orderId != null && !_didNotifyOrderCreated) {
      _didNotifyOrderCreated = true;
      widget.onOrderCreated?.call();
    }

    setState(() {
      _isLoading = false;
      _error = null;
    });

    _startCountdown();
    _startPolling();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted || _isPaid) {
        timer.cancel();
        return;
      }

      if (_secondsLeft <= 1) {
        timer.cancel();
        await _checkPaymentStatus(finalAttempt: true);
        if (!mounted || _isPaid) {
          return;
        }
        setState(() {
          _error = 'QR code expired. Tap refresh to generate a new ABA KHQR.';
        });
        return;
      }

      setState(() {
        _secondsLeft -= 1;
      });
    });
  }

  void _startPolling() {
    final tranId = _payment?.tranId;
    if (tranId == null) {
      return;
    }

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus({bool finalAttempt = false}) async {
    final tranId = _payment?.tranId;
    if (_isCheckingStatus || _isPaid || tranId == null) {
      return;
    }

    _isCheckingStatus = true;
    final status = await PayWayService.getPaymentStatus(
      baseUrl: widget.apiBaseUrl,
      authToken: widget.authToken,
      tranId: tranId,
    );
    _isCheckingStatus = false;

    if (!mounted) {
      return;
    }

    if (status.isPaid) {
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _isPaid = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        PaymentResult(
          success: true,
          orderId: _orderId,
          tranId: tranId,
          message: 'Payment confirmed.',
        ),
      );
      return;
    }

    if (status.isFailed) {
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _error = _describeFailure(status);
      });
      return;
    }

    if (finalAttempt &&
        status.errorMessage != null &&
        status.errorMessage!.isNotEmpty) {
      setState(() {
        _error = status.errorMessage;
      });
    }
  }

  Future<void> _openAbaApp() async {
    final deeplink = _payment?.deeplink;
    if (deeplink == null || deeplink.isEmpty) {
      return;
    }

    try {
      final launched = await launchUrl(
        Uri.parse(deeplink),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        await _copyDeeplink(deeplink);
      }
    } catch (_) {
      if (mounted) {
        await _copyDeeplink(deeplink);
      }
    }
  }

  Future<void> _copyDeeplink(String deeplink) async {
    await Clipboard.setData(ClipboardData(text: deeplink));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ABA deeplink copied to clipboard.')),
    );
  }

  void _closeScreen({required bool success, String? message}) {
    Navigator.of(context).pop(
      PaymentResult(
        success: success,
        orderId: _orderId,
        tranId: _payment?.tranId,
        message: message,
      ),
    );
  }

  String _describeFailure(PayWayStatusResult status) {
    switch ((status.failureReason ?? '').toUpperCase()) {
      case 'QR_EXPIRED':
        return 'This QR code expired before payment completed. Refresh to generate a new one.';
      case 'AMOUNT_MISMATCH':
        return 'ABA reported an amount mismatch. The order was marked as failed for safety.';
      case 'CURRENCY_MISMATCH':
        return 'ABA reported a currency mismatch. The order was marked as failed for safety.';
      default:
        if (status.errorMessage != null && status.errorMessage!.isNotEmpty) {
          return status.errorMessage!;
        }
        return 'Payment was not completed. Please refresh to try again.';
    }
  }

  String _formatCountdown(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F1FF), Color(0xFFF8FBFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _closeScreen(
                        success: false,
                        message: 'Payment cancelled',
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'ABA KHQR Payment',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.12),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                          child: _buildBody(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_isLoading) {
      return SizedBox(
        height: 520,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              'Creating your order and generating the ABA QR...',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_isPaid) {
      return SizedBox(
        height: 520,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFF0F9D58).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF0F9D58),
                size: 54,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Payment confirmed',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We are updating your order now.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final payment = _payment;
    if (payment == null) {
      return _buildErrorState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAbaHeader(context),
        const SizedBox(height: 18),
        Text(
          'KHQR Payment',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0B2F6B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.storeName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B2F6B), Color(0xFF1B5DBF)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(
                'Amount',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '\$${widget.amount.toStringAsFixed(2)} ${widget.currency}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            _PillLabel(
              icon: Icons.timer_outlined,
              text: _formatCountdown(_secondsLeft),
              foregroundColor: _secondsLeft <= 30
                  ? const Color(0xFFB3261E)
                  : const Color(0xFF0B2F6B),
              backgroundColor: _secondsLeft <= 30
                  ? const Color(0xFFFFECE8)
                  : const Color(0xFFE8F1FF),
            ),
            if (payment.tranId != null)
              _PillLabel(
                icon: Icons.receipt_long_outlined,
                text: payment.tranId!,
                foregroundColor: scheme.onSurfaceVariant,
                backgroundColor: const Color(0xFFF2F4F8),
              ),
          ],
        ),
        const SizedBox(height: 22),
        _buildQrCard(context, payment),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F9FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCE7FA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to pay',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B2F6B),
                ),
              ),
              const SizedBox(height: 10),
              const _InstructionLine(
                number: '1',
                text: 'Scan this QR with ABA Mobile or any KHQR-supported app.',
              ),
              const _InstructionLine(
                number: '2',
                text: 'Or tap the button below to open ABA Mobile directly.',
              ),
              const _InstructionLine(
                number: '3',
                text:
                    'This screen checks the verified payment status every 3 seconds.',
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFB3261E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: payment.deeplink == null ? null : _openAbaApp,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Open ABA App'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0B2F6B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _createPayment,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh QR'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () =>
              _closeScreen(success: false, message: 'Payment cancelled'),
          child: const Text('Cancel payment'),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 520,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB3261E),
            size: 56,
          ),
          const SizedBox(height: 14),
          Text(
            _error ?? 'Unable to create ABA payment.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFB3261E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _createPayment,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () =>
                _closeScreen(success: false, message: 'Payment cancelled'),
            child: const Text('Back to checkout'),
          ),
        ],
      ),
    );
  }

  Widget _buildAbaHeader(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD3E2FF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF0B2F6B),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                'ABA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ABA PayWay',
                  style: TextStyle(
                    color: Color(0xFF0B2F6B),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'KHQR secure checkout',
                  style: TextStyle(
                    color: Color(0xFF5A6B89),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard(BuildContext context, PayWayPaymentResult payment) {
    final qrBytes = payment.qrImageBytes;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDCE7FA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120B2F6B),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBFF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5ECF9)),
              ),
              child: Center(
                child: qrBytes != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Image.memory(
                          Uint8List.fromList(qrBytes),
                          fit: BoxFit.contain,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          payment.qrString ?? 'QR data unavailable',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Scan with ABA Mobile or tap the button below.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionLine extends StatelessWidget {
  const _InstructionLine({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF0B2F6B),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({
    required this.icon,
    required this.text,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String text;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
