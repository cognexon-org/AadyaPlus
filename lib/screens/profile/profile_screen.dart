import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/onboarding_widgets.dart' show AuthNote;
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lab_test_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/pharmacy_provider.dart';
import '../../providers/prescription_provider.dart';
import '../chat/chat_list_screen.dart';
import '../home/dashboard_screen.dart';
import '../notifications/notifications_screen.dart';
import '../pathology/pathology_screen.dart';
import '../payments/payments_screen.dart';
import '../pharmacy/pharmacy_orders_screen.dart';
import '../physiotherapy/physiotherapy_screen.dart';
import '../prescriptions/prescriptions_screen.dart';
import '../settings/settings_screen.dart';
import 'addresses_screen.dart';

/// The Profile tab: who you are, your activity on Aadya Plus in numbers,
/// and every account area one tap away.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final visits = context.watch<AppointmentProvider>().appointments.length;
    final rx = context.watch<PrescriptionProvider>().allPrescriptions.length;
    final orders = context.watch<PharmacyProvider>().orders.length + context.watch<LabTestProvider>().orders.length;
    final unread = context.watch<NotificationProvider>().unreadCount;
    void push(Widget w) => Navigator.of(context).push(AppPageRoute(builder: (_) => w));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppTopBar(
        title: 'Profile',
        showBack: false,
        actions: [
          IconButton(tooltip: 'Settings', icon: const Icon(LucideIcons.settings, size: 21), onPressed: () => push(const SettingsScreen())),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          AppEntrance(
            child: Row(
              children: [
                AppAvatar(name: user?.name ?? '', imageUrl: user?.profileImage, size: 68, color: AppColors.brand),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? '',
                        style: AppType.sans(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.textStrong),
                      ),
                      if ((user?.phone ?? '').isNotEmpty)
                        Text('+91 ${user!.phone}', style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary)),
                      if ((user?.email ?? '').isNotEmpty)
                        Text(user!.email, style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Edit name',
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const _NameSheet(),
                  ),
                  style: IconButton.styleFrom(backgroundColor: AppColors.brandVeryLight, foregroundColor: AppColors.brand),
                  icon: const Icon(LucideIcons.pencil, size: 17),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppEntrance(
            index: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: AppColors.brandVeryLight, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  _Stat('$visits', 'Visits', () => DashboardScreen.goTo(1)),
                  Container(width: 1, height: 32, color: AppColors.brandLight),
                  _Stat('$rx', 'Prescriptions', () => push(const PrescriptionsScreen())),
                  Container(width: 1, height: 32, color: AppColors.brandLight),
                  _Stat('$orders', 'Orders', () => push(const PharmacyOrdersScreen())),
                ],
              ),
            ),
          ),
          _Group('Health', [
            _Item(LucideIcons.folderHeart, 'Health records', 'Vitals, allergies, conditions', () => DashboardScreen.goTo(3)),
            _Item(LucideIcons.fileText, 'Prescriptions', null, () => push(const PrescriptionsScreen())),
            _Item(LucideIcons.flaskConical, 'Lab tests & reports', null, () => push(const PathologyScreen()), tone: ModuleAccent.lab.color),
            _Item(LucideIcons.dumbbell, 'Physio & exercises', null, () => push(const PhysiotherapyScreen()), tone: ModuleAccent.physio.color),
          ]),
          _Group('Orders & payments', [
            _Item(LucideIcons.pill, 'Medicine orders', null, () => push(const PharmacyOrdersScreen()), tone: ModuleAccent.pharmacy.color),
            _Item(LucideIcons.receiptIndianRupee, 'Payments & bills', null, () => push(const PaymentsScreen())),
            _Item(LucideIcons.mapPin, 'Saved addresses', null, () => push(const AddressesScreen())),
          ]),
          _Group('Messages', [
            _Item(LucideIcons.messagesSquare, 'Chats with your care team', null, () => push(const ChatListScreen())),
            _Item(LucideIcons.bell, 'Notifications', unread > 0 ? '$unread unread' : null, () => push(const NotificationsScreen())),
          ]),
          _Group('Account', [
            _Item(LucideIcons.settings, 'Settings', 'Notifications, password', () => push(const SettingsScreen())),
          ]),
          const SizedBox(height: 18),
          AppSecondaryButton(
            label: 'Sign out',
            icon: LucideIcons.logOut,
            color: AppColors.error,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
                  ],
                ),
              );
              if (ok == true) auth.logout();
            },
          ),
          const SizedBox(height: 14),
          Center(
            child: Text('Aadya Plus', style: AppType.sans(fontSize: AppType.caption, color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback onTap;
  const _Stat(this.value, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: AppType.sans(fontSize: AppType.figure, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
          Text(label, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
        ],
      ),
    ),
  );
}

class _Item {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color tone;
  const _Item(this.icon, this.title, this.subtitle, this.onTap, {this.tone = AppColors.brand});
}

class _Group extends StatelessWidget {
  final String title;
  final List<_Item> items;
  const _Group(this.title, this.items);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderStrong)),
          child: Column(
            children: [
              for (final (i, it) in items.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 60),
                InkWell(
                  onTap: it.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(i == 0 ? 18 : 0),
                    bottom: Radius.circular(i == items.length - 1 ? 18 : 0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(color: Color.alphaBlend(it.tone.withValues(alpha: 0.1), Colors.white), borderRadius: BorderRadius.circular(10)),
                          child: Icon(it.icon, size: 17, color: it.tone),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.title, style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w600, color: AppColors.textStrong)),
                              if (it.subtitle != null)
                                Text(it.subtitle!, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _NameSheet extends StatefulWidget {
  const _NameSheet();

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _name = TextEditingController(text: context.read<AuthProvider>().user?.name ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter your full name');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().updateName(_name.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your name', style: AppType.sans(fontSize: AppType.heading + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
          const SizedBox(height: 4),
          Text('As it should appear on prescriptions and reports.', style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          AppTextField(label: '', hint: 'Full name', controller: _name, icon: LucideIcons.user, textCapitalization: TextCapitalization.words, margin: EdgeInsets.zero),
          if (_error != null) ...[const SizedBox(height: 10), AuthNote.error(_error!)],
          const SizedBox(height: 16),
          AppButton(label: 'Save', loading: _busy, onPressed: _save),
        ],
      ),
    ),
  );
}
