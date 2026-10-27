import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/onboarding_widgets.dart' show AuthNote;
import '../../providers/pharmacy_provider.dart';
import '../../widgets/address_sheet.dart';
import '../payments/payment_checkout_screen.dart';
import 'pharmacy_order_details_screen.dart';
import 'pharmacy_widgets.dart';

/// Checkout: where to deliver, the prescription when one is needed, how to
/// pay and any coupon — with the bill worked out by the server as each
/// choice changes, so the total shown is the total charged.
class EPharmacyCheckoutScreen extends StatefulWidget {
  const EPharmacyCheckoutScreen({super.key});

  @override
  State<EPharmacyCheckoutScreen> createState() => _EPharmacyCheckoutScreenState();
}

class _EPharmacyCheckoutScreenState extends State<EPharmacyCheckoutScreen> {
  String? _addressId;
  late String _payment;
  String? _rxChoice; // 'rx:<id>' or 'upload:<id>'
  final _coupon = TextEditingController();
  String? _appliedCoupon;
  final _note = TextEditingController();
  Map<String, dynamic>? _quote;
  bool _quoting = false;
  bool _placing = false;
  bool _uploading = false;
  String? _error;
  int _quoteRun = 0;

  Map<String, dynamic> get _eco => mapOf(context.read<PharmacyProvider>().selectedStore?['ecommerce']);
  bool get _codOk => _eco['codEnabled'] != false;
  bool get _onlineOk => _eco['onlinePaymentEnabled'] != false;

  bool get _needsRx => context.read<PharmacyProvider>().cartItems.any((l) => mapOf(l['medicine'])['prescriptionRequired'] == true);

  String? get _prescriptionId => _rxChoice?.startsWith('rx:') == true ? _rxChoice!.substring(3) : null;
  String? get _uploadId => _rxChoice?.startsWith('upload:') == true ? _rxChoice!.substring(7) : null;

  @override
  void initState() {
    super.initState();
    _payment = 'online';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<PharmacyProvider>();
      if (!_onlineOk && _codOk) _payment = 'cod';
      await p.loadCheckoutData();
      if (!mounted) return;
      final def = p.addresses.where((a) => a['isDefault'] == true);
      setState(() {
        _addressId = def.isNotEmpty ? idOf(def.first) : (p.addresses.isNotEmpty ? idOf(p.addresses.first) : null);
        final preferred = p.preferredPrescriptionId;
        if (preferred != null && p.prescriptions.any((r) => idOf(r) == preferred)) _rxChoice = 'rx:$preferred';
      });
      _requote();
    });
  }

  @override
  void dispose() {
    _coupon.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _ready => _addressId != null && (!_needsRx || _rxChoice != null);

  Future<void> _requote() async {
    if (!_ready) {
      setState(() => _quote = null);
      return;
    }
    final run = ++_quoteRun;
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final q = await context.read<PharmacyProvider>().quote(
        addressId: _addressId!,
        paymentMethod: _payment,
        couponCode: _appliedCoupon,
        prescriptionId: _prescriptionId,
        prescriptionUploadId: _uploadId,
      );
      if (mounted && run == _quoteRun) setState(() => _quote = q);
    } catch (e) {
      if (!mounted || run != _quoteRun) return;
      final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      setState(() {
        _quote = null;
        _error = message;
        // A coupon the server refuses comes off, and the bill is redone without it.
        if (_appliedCoupon != null && message.toLowerCase().contains('coupon')) {
          _appliedCoupon = null;
          WidgetsBinding.instance.addPostFrameCallback((_) => _requote());
        }
      });
    } finally {
      if (mounted && run == _quoteRun) setState(() => _quoting = false);
    }
  }

  Future<void> _addAddress() async {
    final saved = await showAddressSheet(context);
    if (saved != null && mounted) {
      setState(() => _addressId = idOf(saved));
      _requote();
    }
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final upload = await context.read<PharmacyProvider>().uploadPrescription(path);
      if (!mounted) return;
      setState(() => _rxChoice = 'upload:${idOf(upload)}');
      _requote();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _place() async {
    if (!_ready || _quote == null) return;
    setState(() {
      _placing = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final order = await context.read<PharmacyProvider>().placeOrder(
        addressId: _addressId!,
        paymentMethod: _payment,
        couponCode: _appliedCoupon,
        prescriptionId: _prescriptionId,
        prescriptionUploadId: _uploadId,
        deliveryInstructions: _note.text.trim(),
      );
      final id = idOf(order);
      if (_payment == 'online') {
        final paid = await nav.push<bool>(AppPageRoute(
          builder: (_) => PaymentCheckoutScreen(
            entityType: 'pharmacy_order',
            entityId: id,
            title: 'Medicine order ${order['orderNumber'] ?? ''}',
            expectedAmount: asDouble(order['totalAmount']),
          ),
        ));
        if (paid != true) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Order saved. Pay within 30 minutes from the order screen to confirm it.'),
          ));
        }
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Order placed')));
      }
      nav.pushAndRemoveUntil(
        AppPageRoute(builder: (_) => PharmacyOrderDetailsScreen(orderId: id)),
        (r) => r.isFirst,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PharmacyProvider>();
    final q = _quote;
    return ModuleTheme(
      accent: pharmacyAccent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(title: 'Checkout', subtitle: (p.selectedStore?['name'] ?? '').toString()),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            _Section(
              title: 'Deliver to',
              action: 'Add new',
              onAction: _addAddress,
              child: p.addresses.isEmpty
                  ? _EmptyChoice(icon: LucideIcons.mapPinPlus, text: 'Add the address to deliver to', onTap: _addAddress)
                  : Column(
                      children: [
                        for (final a in p.addresses)
                          _Choice(
                            selected: _addressId == idOf(a),
                            icon: switch ((a['label'] ?? '').toString()) {
                              'Work' => LucideIcons.briefcase,
                              'Other' => LucideIcons.mapPin,
                              _ => LucideIcons.house,
                            },
                            title: '${a['label'] ?? 'Address'} · ${a['contactName'] ?? ''}',
                            subtitle: [a['line1'], a['line2'], a['city'], a['pincode']]
                                .where((e) => e != null && e.toString().trim().isNotEmpty)
                                .join(', '),
                            onTap: () {
                              setState(() => _addressId = idOf(a));
                              _requote();
                            },
                          ),
                      ],
                    ),
            ),
            if (_needsRx)
              _Section(
                title: 'Prescription',
                caption: 'Some medicines need a valid prescription. The pharmacist checks it before packing.',
                child: Column(
                  children: [
                    for (final r in p.prescriptions)
                      _Choice(
                        selected: _rxChoice == 'rx:${idOf(r)}',
                        icon: LucideIcons.fileCheck,
                        title: 'Rx ${r['prescriptionNumber'] ?? ''}',
                        subtitle: [
                          mapOf(r['doctorId'])['name'] ?? mapOf(r['physioId'])['name'],
                          '${mapsOf(r['medicines']).length} medicines',
                        ].where((e) => e != null).join(' · '),
                        onTap: () {
                          setState(() => _rxChoice = 'rx:${idOf(r)}');
                          _requote();
                        },
                      ),
                    for (final u in p.uploads.where((u) => u['status'] != 'rejected'))
                      _Choice(
                        selected: _rxChoice == 'upload:${idOf(u)}',
                        icon: LucideIcons.fileImage,
                        title: (u['originalName'] ?? 'Uploaded prescription').toString(),
                        subtitle: PatientStatus.of(u['status'] == 'pending' ? 'pending_review' : u['status']?.toString()).label,
                        onTap: () {
                          setState(() => _rxChoice = 'upload:${idOf(u)}');
                          _requote();
                        },
                      ),
                    _EmptyChoice(
                      icon: _uploading ? null : LucideIcons.upload,
                      text: _uploading ? 'Uploading…' : 'Upload a photo or PDF',
                      onTap: _uploading ? null : _upload,
                    ),
                  ],
                ),
              ),
            _Section(
              title: 'Pay with',
              child: Row(
                children: [
                  if (_onlineOk)
                    Expanded(
                      child: _PayOption(
                        icon: LucideIcons.creditCard,
                        title: 'Pay online',
                        caption: 'UPI, cards, netbanking',
                        selected: _payment == 'online',
                        onTap: () {
                          setState(() => _payment = 'online');
                          _requote();
                        },
                      ),
                    ),
                  if (_onlineOk && _codOk) const SizedBox(width: 10),
                  if (_codOk)
                    Expanded(
                      child: _PayOption(
                        icon: LucideIcons.banknote,
                        title: 'Cash on delivery',
                        caption: 'Pay when it arrives',
                        selected: _payment == 'cod',
                        onTap: () {
                          setState(() => _payment = 'cod');
                          _requote();
                        },
                      ),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Coupon',
              child: _appliedCoupon != null
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: pharmacyAccent.veryLight, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Icon(LucideIcons.ticketPercent, size: 19, color: pharmacyAccent.color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q != null && asDouble(q['couponDiscount']) > 0
                                  ? '$_appliedCoupon applied · you save ${appRupees(q['couponDiscount'])}'
                                  : '$_appliedCoupon applied',
                              style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: pharmacyAccent.color),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _appliedCoupon = null);
                              _requote();
                            },
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: '',
                            hint: 'Enter coupon code',
                            controller: _coupon,
                            icon: LucideIcons.ticketPercent,
                            textCapitalization: TextCapitalization.characters,
                            margin: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 10),
                        AppSecondaryButton(
                          label: 'Apply',
                          fullWidth: false,
                          onPressed: () {
                            final code = _coupon.text.trim().toUpperCase();
                            if (code.isEmpty) return;
                            setState(() => _appliedCoupon = code);
                            _requote();
                          },
                        ),
                      ],
                    ),
            ),
            _Section(
              title: 'Delivery note',
              optional: true,
              child: AppTextField(
                label: '',
                hint: 'E.g. call on arrival, leave with the guard',
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                margin: EdgeInsets.zero,
              ),
            ),
            _Section(
              title: 'Bill',
              child: AnimatedSwitcher(
                duration: AppMotion.medium,
                child: q == null
                    ? Container(
                        key: const ValueKey('none'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14)),
                        child: Text(
                          _quoting
                              ? 'Working out your total…'
                              : _addressId == null
                              ? 'Add an address to see the total'
                              : _needsRx && _rxChoice == null
                              ? 'Choose a prescription to see the total'
                              : 'The total will show here',
                          style: AppType.sans(fontSize: AppType.body, color: AppColors.textSecondary),
                        ),
                      )
                    : AppCard(
                        key: ValueKey(q['totalAmount']),
                        child: Column(
                          children: [
                            BillLine('Items', appRupees(q['merchandiseTotal'] ?? (asDouble(q['subtotal']) + asDouble(q['tax'])))),
                            if (asDouble(q['medicineDiscount']) > 0)
                              BillLine('Discount on items', '−${appRupees(q['medicineDiscount'])}', valueColor: pharmacyAccent.color),
                            if (asDouble(q['couponDiscount']) > 0)
                              BillLine('Coupon', '−${appRupees(q['couponDiscount'])}', valueColor: pharmacyAccent.color),
                            BillLine(
                              'Delivery',
                              asDouble(q['deliveryFee']) > 0 ? appRupees(q['deliveryFee']) : 'Free',
                              valueColor: asDouble(q['deliveryFee']) > 0 ? null : pharmacyAccent.color,
                            ),
                            const Divider(height: 18),
                            BillLine('To pay', appRupees(q['totalAmount']), strong: true),
                            if (asDouble(q['tax']) > 0)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Includes ${appRupees(q['tax'])} GST',
                                  style: AppType.sans(fontSize: AppType.caption, color: AppColors.textTertiary),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 4), AuthNote.error(_error!, onClose: () => setState(() => _error = null))],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: AppButton(
              label: q == null
                  ? 'Place order'
                  : _payment == 'online'
                  ? 'Pay ${appRupees(q['totalAmount'])}'
                  : 'Place order · ${appRupees(q['totalAmount'])}',
              icon: _payment == 'online' ? LucideIcons.lock : LucideIcons.check,
              loading: _placing || _quoting,
              onPressed: q == null ? null : _place,
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? caption;
  final String? action;
  final VoidCallback? onAction;
  final bool optional;
  final Widget child;
  const _Section({required this.title, required this.child, this.caption, this.action, this.onAction, this.optional = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
            if (optional) ...[
              const SizedBox(width: 6),
              Text('Optional', style: AppType.sans(fontSize: AppType.caption, color: AppColors.textTertiary)),
            ],
            const Spacer(),
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: pharmacyAccent.color, minimumSize: const Size(0, 32)),
                child: Text(action!),
              ),
          ],
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(caption!, style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textSecondary)),
          ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _Choice extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Choice({required this.selected, required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      selected: selected,
      button: true,
      child: AppPressable(
        onTap: onTap,
        scale: 0.99,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? pharmacyAccent.veryLight : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? pharmacyAccent.color : AppColors.borderStrong, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: selected ? pharmacyAccent.color : AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.sans(fontSize: AppType.caption, height: 1.35, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  key: ValueKey(selected),
                  size: 20,
                  color: selected ? pharmacyAccent.color : AppColors.borderStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EmptyChoice extends StatelessWidget {
  final IconData? icon;
  final String text;
  final VoidCallback? onTap;
  const _EmptyChoice({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pharmacyAccent.light, width: 1.2),
        color: pharmacyAccent.veryLight.withValues(alpha: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon == null
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: pharmacyAccent.color))
              : Icon(icon, size: 18, color: pharmacyAccent.color),
          const SizedBox(width: 8),
          Text(text, style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: pharmacyAccent.color)),
        ],
      ),
    ),
  );
}

class _PayOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  final bool selected;
  final VoidCallback onTap;
  const _PayOption({required this.icon, required this.title, required this.caption, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: AppPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? pharmacyAccent.veryLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? pharmacyAccent.color : AppColors.borderStrong, width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: selected ? pharmacyAccent.color : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(title, style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
            Text(caption, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
          ],
        ),
      ),
    ),
  );
}
