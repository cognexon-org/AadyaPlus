import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/onboarding_widgets.dart' show AuthNote;
import '../../providers/auth_provider.dart';
import '../profile/addresses_screen.dart';

/// Settings that are saved to the account: which channels we may reach you
/// on, your password, your addresses.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _toggle(BuildContext context, String channel, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthProvider>().updateNotificationChannels({channel: value});
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '')), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppTopBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          const _Head('Notifications'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderStrong)),
            child: Column(
              children: [
                AppSwitchRow(
                  label: 'App notifications',
                  subtitle: 'Booking updates, reports, order tracking',
                  icon: LucideIcons.bell,
                  value: user?.notifies('push') ?? true,
                  onChanged: (v) => _toggle(context, 'push', v),
                ),
                AppSwitchRow(
                  label: 'SMS',
                  subtitle: 'Reminders and codes by text',
                  icon: LucideIcons.messageSquareText,
                  value: user?.notifies('sms') ?? true,
                  onChanged: (v) => _toggle(context, 'sms', v),
                ),
                AppSwitchRow(
                  label: 'Email',
                  subtitle: 'Receipts and summaries',
                  icon: LucideIcons.mail,
                  value: user?.notifies('email') ?? true,
                  onChanged: (v) => _toggle(context, 'email', v),
                ),
              ],
            ),
          ),
          const _Head('Account'),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderStrong)),
            child: Column(
              children: [
                _Row(
                  icon: LucideIcons.lockKeyhole,
                  title: 'Change password',
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const _PasswordSheet(),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _Row(
                  icon: LucideIcons.mapPin,
                  title: 'Saved addresses',
                  onTap: () => Navigator.of(context).push(AppPageRoute(builder: (_) => const AddressesScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Signed in as ${user?.email.isNotEmpty == true ? user!.email : '+91 ${user?.phone ?? ''}'}',
            textAlign: TextAlign.center,
            style: AppType.sans(fontSize: AppType.caption, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  final String text;
  const _Head(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(text, style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(icon, size: 20, color: AppColors.brand),
    title: Text(title, style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w600, color: AppColors.textStrong)),
    trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textTertiary),
  );
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_current.text.isEmpty) return setState(() => _error = 'Enter your current password');
    if (_next.text.length < 6) return setState(() => _error = 'Use at least 6 characters');
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthProvider>().changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Password changed')));
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
          Text('Change password', style: AppType.sans(fontSize: AppType.heading + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
          const SizedBox(height: 14),
          AppTextField(label: '', hint: 'Current password', controller: _current, icon: LucideIcons.lockKeyhole, obscureText: _hide, margin: const EdgeInsets.only(bottom: 10)),
          AppTextField(
            label: '',
            hint: 'New password',
            controller: _next,
            icon: LucideIcons.keyRound,
            obscureText: _hide,
            margin: EdgeInsets.zero,
            trailing: IconButton(
              tooltip: _hide ? 'Show' : 'Hide',
              onPressed: () => setState(() => _hide = !_hide),
              icon: Icon(_hide ? LucideIcons.eye : LucideIcons.eyeOff, size: 18, color: AppColors.textTertiary),
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 10), AuthNote.error(_error!)],
          const SizedBox(height: 16),
          AppButton(label: 'Change password', loading: _busy, onPressed: _save),
        ],
      ),
    ),
  );
}
