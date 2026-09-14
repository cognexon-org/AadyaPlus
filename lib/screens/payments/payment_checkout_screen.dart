import 'package:aadya_plus/providers/auth_provider.dart';
import 'package:aadya_plus/services/payment_service.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentCheckoutScreen extends StatefulWidget {
  final String entityType;
  final String entityId;
  final String title;
  final double expectedAmount;

  const PaymentCheckoutScreen({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.expectedAmount,
  });

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  final Razorpay _razorpay = Razorpay();
  PaymentOrderData? _pendingOrder;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _startPayment() async {
    if (AppConstants.razorpayKeyId.isEmpty) {
      setState(() {
        _error = 'AADYA_RAZORPAY_KEY_ID is not configured for this build.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final order = await PaymentService.instance.createOrder(
        entityType: widget.entityType,
        entityId: widget.entityId,
      );
      _pendingOrder = order;

      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      final options = <String, dynamic>{
        'key': AppConstants.razorpayKeyId,
        'amount': order.amountPaise,
        'currency': order.currency,
        'name': 'Aadya Plus',
        'description': widget.title,
        'order_id': order.orderId,
        'prefill': {
          'contact': user?.phone ?? '',
          'email': user?.email ?? '',
        },
        'theme': {'color': '#0284C7'},
      };

      setState(() => _busy = false);
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final order = _pendingOrder;
    final paymentId = response.paymentId;
    final orderId = response.orderId ?? order?.orderId;
    final signature = response.signature;

    if (order == null || paymentId == null || orderId == null || signature == null) {
      if (mounted) {
        setState(() => _error = 'The payment completed but verification data was incomplete.');
      }
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await PaymentService.instance.verify(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
        entityType: order.entityType,
        entityId: order.entityId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment verified successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Payment verification failed: ${e.toString()}';
      });
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = response.message ?? 'Payment was cancelled or failed.';
    });
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet selected: ${response.walletName ?? 'wallet'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Secure Payment'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pay for', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 6),
                  Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '₹${widget.expectedAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: AppConstants.primaryColor),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The final payable amount is generated by the AadyaMed server. The app does not send a client-calculated amount to the payment gateway.',
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _startPayment,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.lock_outline),
                label: Text(_busy ? 'Preparing payment...' : 'Pay securely'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
