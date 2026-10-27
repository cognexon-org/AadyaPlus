import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/onboarding_widgets.dart' show AuthNote;
import '../../providers/lab_test_provider.dart';
import '../../providers/pharmacy_provider.dart';
import '../../widgets/address_sheet.dart';
import '../payments/payment_checkout_screen.dart';
import '../pathology/diagnostic_order_details_screen.dart';
import 'lab_test_screen.dart' show labAccent;

/// Book the test cart: visit the lab or have a sample collected at home,
/// pick a slot with room, and see exactly what it costs.
class DiagnosticBookingScreen extends StatefulWidget {
  const DiagnosticBookingScreen({super.key});

  @override
  State<DiagnosticBookingScreen> createState() => _DiagnosticBookingScreenState();
}

class _DiagnosticBookingScreenState extends State<DiagnosticBookingScreen> {
  late String _type = _homeSupported ? 'home_collection' : 'lab_visit';
  late DateTime _date = _today;
  List<Map<String, dynamic>>? _slots;
  Map<String, dynamic>? _slot;
  String? _addressId;
  final _notes = TextEditingController();
  bool _booking = false;
  String? _error;
  String? _slotError;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Map<String, dynamic> get _lab => context.read<LabTestProvider>().cartLab ?? const {};
  bool get _homeSupported => _lab['homeCollectionAvailable'] == true;
  double get _collection => _type == 'home_collection' ? asDouble(_lab['homeCollectionCharges']) : 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadSlots();
      final pharmacy = context.read<PharmacyProvider>();
      await pharmacy.loadCheckoutData();
      if (!mounted) return;
      final def = pharmacy.addresses.where((a) => a['isDefault'] == true);
      setState(() => _addressId = def.isNotEmpty ? idOf(def.first) : (pharmacy.addresses.isNotEmpty ? idOf(pharmacy.addresses.first) : null));
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    final date = _date;
    final labId = context.read<LabTestProvider>().cartLabId;
    if (labId == null) return;
    setState(() {
      _slots = null;
      _slot = null;
      _slotError = null;
    });
    try {
      final slots = await context.read<LabTestProvider>().slots(labId, date);
      if (!mounted || date != _date) return;
      final now = DateTime.now();
      setState(() => _slots = slots.where((s) {
        if (s['isAvailable'] == false || (s['availableCapacity'] as num? ?? 1) <= 0) return false;
        if (date != _today) return true;
        final p = (s['startTime'] ?? '').toString().split(':');
        if (p.length < 2) return false;
        return DateTime(date.year, date.month, date.day, int.parse(p[0]), int.parse(p[1])).isAfter(now);
      }).toList());
    } catch (e) {
      if (mounted && date == _date) setState(() => _slotError = e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), ''));
    }
  }

  String _time(String hhmm) {
    final p = hhmm.split(':');
    if (p.length < 2) return hhmm;
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1])));
  }

  Future<void> _book() async {
    final lab = context.read<LabTestProvider>();
    final pharmacy = context.read<PharmacyProvider>();
    if (_slot == null) {
      setState(() => _error = 'Choose a time slot');
      return;
    }
    Map<String, dynamic>? address;
    if (_type == 'home_collection') {
      final a = pharmacy.addresses.where((x) => idOf(x) == _addressId);
      if (a.isEmpty) {
        setState(() => _error = 'Add the address for sample collection');
        return;
      }
      final x = a.first;
      address = {
        for (final k in ['contactName', 'phone', 'line1', 'line2', 'landmark', 'city', 'state', 'pincode'])
          if ((x[k] ?? '').toString().isNotEmpty) k: x[k],
      };
    }
    setState(() {
      _booking = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      final order = await lab.bookCart(
        date: _date,
        startTime: (_slot!['startTime'] ?? '').toString(),
        endTime: (_slot!['endTime'] ?? '').toString(),
        type: _type,
        collectionAddress: address,
        patientInstructions: _notes.text.trim(),
      );
      HapticFeedback.mediumImpact();
      final id = idOf(order);
      final amount = asDouble(order['totalAmount']);
      if (amount > 0) {
        await nav.push<bool>(AppPageRoute(
          builder: (_) => PaymentCheckoutScreen(entityType: 'labtest', entityId: id, title: 'Lab tests', expectedAmount: amount),
        ));
      }
      nav.pushAndRemoveUntil(
        AppPageRoute(builder: (_) => DiagnosticOrderDetailsScreen(orderId: id, justBooked: true)),
        (r) => r.isFirst,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), ''));
        _loadSlots();
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lab = context.watch<LabTestProvider>();
    final pharmacy = context.watch<PharmacyProvider>();
    final items = lab.cart;
    final total = lab.cartSubtotal + _collection;
    if (items.isEmpty) {
      return Scaffold(
        appBar: const AppTopBar(title: 'Book tests'),
        body: Center(
          child: AppEmptyState(
            illustration: Illustrations.labReport,
            title: 'No tests chosen',
            actionLabel: 'Browse tests',
            onAction: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }
    return ModuleTheme(
      accent: labAccent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(title: 'Book tests', subtitle: (lab.cartLab?['labName'] ?? '').toString()),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            AppCard(
              child: Column(
                children: [
                  for (final (i, r) in items.indexed) ...[
                    if (i > 0) const Divider(height: 16),
                    Row(
                      children: [
                        Icon(r['kind'] == 'package' ? LucideIcons.packageOpen : LucideIcons.flaskConical, size: 17, color: labAccent.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ((r['kind'] == 'package' ? mapOf(r['item'])['packageName'] : mapOf(r['item'])['testName']) ?? 'Test').toString(),
                            style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w600, color: AppColors.textStrong),
                          ),
                        ),
                        Text(appRupees(mapOf(r['item'])['price']), style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700)),
                        IconButton(
                          tooltip: 'Remove',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => lab.removeFromCart(r),
                          icon: const Icon(LucideIcons.x, size: 16, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (items.any((r) => mapOf(r['item'])['fastingRequired'] == true))
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(LucideIcons.utensilsCrossed, size: 17, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fasting needed — don’t eat for 8–12 hours before. Water is fine. Pick a morning slot.',
                        style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            const _Step('Where should the sample be taken?'),
            Row(
              children: [
                Expanded(
                  child: _TypeCard(
                    icon: LucideIcons.house,
                    title: 'At home',
                    caption: !_homeSupported
                        ? 'Not offered by this lab'
                        : asDouble(_lab['homeCollectionCharges']) > 0
                        ? '+${appRupees(_lab['homeCollectionCharges'])}'
                        : 'Free pickup',
                    selected: _type == 'home_collection',
                    enabled: _homeSupported,
                    onTap: () => setState(() => _type = 'home_collection'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TypeCard(
                    icon: LucideIcons.building2,
                    title: 'At the lab',
                    caption: 'Walk in at your slot',
                    selected: _type == 'lab_visit',
                    enabled: true,
                    onTap: () => setState(() => _type = 'lab_visit'),
                  ),
                ),
              ],
            ),
            if (_type == 'home_collection') ...[
              const _Step('Collect from'),
              for (final a in pharmacy.addresses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AddressTile(address: a, selected: _addressId == idOf(a), onTap: () => setState(() => _addressId = idOf(a))),
                ),
              TextButton.icon(
                onPressed: () async {
                  final saved = await showAddressSheet(context);
                  if (saved != null && mounted) setState(() => _addressId = idOf(saved));
                },
                icon: const Icon(LucideIcons.mapPinPlus, size: 17),
                label: const Text('Add address'),
                style: TextButton.styleFrom(foregroundColor: labAccent.color),
              ),
            ],
            const _Step('Pick a day'),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = _today.add(Duration(days: i));
                  final sel = d == _date;
                  return AppPressable(
                    onTap: () {
                      if (sel) return;
                      setState(() => _date = d);
                      _loadSlots();
                    },
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      width: 56,
                      decoration: BoxDecoration(color: sel ? labAccent.color : AppColors.panel, borderRadius: BorderRadius.circular(15)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            i == 0 ? 'Today' : i == 1 ? 'Tmrw' : DateFormat('EEE').format(d),
                            style: AppType.sans(fontSize: AppType.caption, color: sel ? Colors.white70 : AppColors.textSecondary),
                          ),
                          Text('${d.day}', style: AppType.sans(fontSize: 19, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.textStrong)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const _Step('Pick a time'),
            AnimatedSize(
              duration: AppMotion.medium,
              alignment: Alignment.topCenter,
              child: _slotError != null
                  ? AppErrorBanner(message: _slotError!, onRetry: _loadSlots)
                  : _slots == null
                  ? AppShimmer(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (var i = 0; i < 6; i++) const AppSkeletonBlock(width: 104, height: 42, radius: 12)],
                      ),
                    )
                  : _slots!.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14)),
                      child: Text('No free slots on this day. Try the next one.', style: AppType.sans(fontSize: AppType.body, color: AppColors.textSecondary)),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in _slots!)
                          AppPressable(
                            onTap: () => setState(() {
                              _slot = s;
                              _error = null;
                            }),
                            scale: 0.95,
                            child: AnimatedContainer(
                              duration: AppMotion.fast,
                              width: 104,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: identical(_slot, s) ? labAccent.color : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: identical(_slot, s) ? labAccent.color : AppColors.borderStrong),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _time((s['startTime'] ?? '').toString()),
                                    style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: identical(_slot, s) ? Colors.white : AppColors.textStrong),
                                  ),
                                  if ((s['availableCapacity'] as num? ?? 9) <= 2)
                                    Text(
                                      '${s['availableCapacity']} left',
                                      style: AppType.sans(fontSize: AppType.micro, fontWeight: FontWeight.w600, color: identical(_slot, s) ? Colors.white70 : AppColors.warning),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const _Step('Notes for the lab', optional: true),
            AppTextField(
              label: '',
              hint: 'E.g. ring the bell, I’m on blood thinners',
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: 18),
            AppCard(
              child: Column(
                children: [
                  _Bill('Tests (${items.length})', appRupees(lab.cartSubtotal)),
                  if (_type == 'home_collection') _Bill('Home collection', _collection > 0 ? appRupees(_collection) : 'Free'),
                  const Divider(height: 18),
                  _Bill('Total', appRupees(total), strong: true),
                ],
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 12), AuthNote.error(_error!, onClose: () => setState(() => _error = null))],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: AppButton(
              label: _slot == null ? 'Choose a time' : 'Book · ${appRupees(total)}',
              loading: _booking,
              onPressed: _slot == null ? null : _book,
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String text;
  final bool optional;
  const _Step(this.text, {this.optional = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Row(
      children: [
        Text(text, style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
        if (optional) ...[
          const SizedBox(width: 6),
          Text('Optional', style: AppType.sans(fontSize: AppType.caption, color: AppColors.textTertiary)),
        ],
      ],
    ),
  );
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _TypeCard({required this.icon, required this.title, required this.caption, required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : 0.5,
    child: AppPressable(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? labAccent.veryLight : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? labAccent.color : AppColors.borderStrong, width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: selected ? labAccent.color : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(title, style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
            Text(caption, style: AppType.sans(fontSize: AppType.caption, color: selected ? labAccent.color : AppColors.textSecondary)),
          ],
        ),
      ),
    ),
  );
}

class _AddressTile extends StatelessWidget {
  final Map<String, dynamic> address;
  final bool selected;
  final VoidCallback onTap;
  const _AddressTile({required this.address, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onTap,
    scale: 0.99,
    child: AnimatedContainer(
      duration: AppMotion.fast,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? labAccent.veryLight : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? labAccent.color : AppColors.borderStrong, width: selected ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.mapPin, size: 18, color: selected ? labAccent.color : AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${address['label'] ?? 'Address'} · ${[address['line1'], address['city'], address['pincode']].where((e) => e != null && e.toString().isNotEmpty).join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.sans(fontSize: AppType.small, color: AppColors.textPrimary),
            ),
          ),
          Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle, size: 19, color: selected ? labAccent.color : AppColors.borderStrong),
        ],
      ),
    ),
  );
}

class _Bill extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _Bill(this.label, this.value, {this.strong = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppType.sans(
              fontSize: strong ? AppType.title : AppType.body,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              color: strong ? AppColors.textStrong : AppColors.textSecondary,
            ),
          ),
        ),
        Text(value, style: AppType.sans(fontSize: strong ? AppType.title + 1 : AppType.body, fontWeight: strong ? FontWeight.w800 : FontWeight.w600, color: AppColors.textStrong)),
      ],
    ),
  );
}
