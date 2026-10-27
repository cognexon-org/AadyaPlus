import 'package:aadya_plus/models/payment_record.dart';
import 'package:aadya_plus/providers/auth_provider.dart';
import 'package:aadya_plus/services/payment_service.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:aadya_plus/core/ui/app_ui.dart';
import 'package:aadya_plus/features/onboarding/onboarding_widgets.dart' show AuthNote;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
      // The server sends its publishable key; a build-time key is the
      // fallback for an older backend.
      final keyId = order.keyId.isNotEmpty
          ? order.keyId
          : AppConstants.razorpayKeyId;
      if (keyId.isEmpty) {
        throw Exception('Online payment isn’t available right now.');
      }

      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      final options = <String, dynamic>{
        'key': keyId,
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
        const SnackBar(content: Text('Payment received')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'We couldn’t confirm the payment yet. If money was taken it will be matched automatically or refunded.';
      });
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = response.code == Razorpay.PAYMENT_CANCELLED ? 'Payment cancelled' : (response.message ?? 'The payment didn’t go through');
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
    final accent = switch (widget.entityType) {
      'labtest' => ModuleAccent.lab,
      'pharmacy_order' => ModuleAccent.pharmacy,
      _ => ModuleAccent.brand,
    };
    return ModuleTheme(
      accent: accent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: const AppTopBar(title: 'Payment'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const AppEntrance(child: AppIllustration(Illustrations.payments, height: 140, float: true)),
            const SizedBox(height: 22),
            AppEntrance(
              index: 1,
              child: Column(
                children: [
                  Text(widget.title, textAlign: TextAlign.center, style: AppType.sans(fontSize: AppType.body + 0.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    appRupees(widget.expectedAmount),
                    style: AppType.sans(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: AppColors.textStrong),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppEntrance(
              index: 2,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    for (final (icon, text) in const [
                      (LucideIcons.smartphone, 'UPI, cards, netbanking and wallets'),
                      (LucideIcons.shieldCheck, 'Secured by Razorpay — we never see your card details'),
                      (LucideIcons.rotateCcw, 'If a booking is cancelled, the refund goes back to how you paid'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Icon(icon, size: 17, color: accent.color),
                            const SizedBox(width: 10),
                            Expanded(child: Text(text, style: AppType.sans(fontSize: AppType.small, height: 1.35, color: AppColors.textPrimary))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              AuthNote.error(_error!.replaceFirst(RegExp(r'^\w*Exception:\s*'), ''), onClose: () => setState(() => _error = null)),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: AppButton(
              label: _busy ? 'Getting things ready…' : 'Pay ${appRupees(widget.expectedAmount)}',
              icon: LucideIcons.lock,
              loading: _busy,
              onPressed: _startPayment,
            ),
          ),
        ),
      ),
    );
  }
}
