import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../core/ui/app_ui.dart';
import '../features/onboarding/onboarding_widgets.dart' show AuthNote;
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/pharmacy_provider.dart';

/// Add a delivery address. Name and phone come from the account and the
/// city and pincode from the current location, so most people only type
/// the house line. Returns the saved address.
Future<Map<String, dynamic>?> showAddressSheet(BuildContext context) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddressSheet(),
    );

class _AddressSheet extends StatefulWidget {
  const _AddressSheet();

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late final _user = context.read<AuthProvider>().user;
  late final _location = context.read<LocationProvider>();
  late final _name = TextEditingController(text: _user?.name ?? '');
  late final _phone = TextEditingController(text: _user?.phone ?? '');
  final _line1 = TextEditingController();
  late final _line2 = TextEditingController(text: _location.label ?? '');
  final _landmark = TextEditingController();
  late final _city = TextEditingController(text: _location.city ?? '');
  final _state = TextEditingController();
  late final _pincode = TextEditingController(text: _location.pincode ?? '');
  String _label = 'Home';
  bool _default = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _line1, _line2, _landmark, _city, _state, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    String? problem;
    if (_name.text.trim().isEmpty) problem = 'Add the name to deliver to';
    if (problem == null && _phone.text.trim().length != 10) problem = 'Add a 10-digit phone number';
    if (problem == null && _line1.text.trim().isEmpty) problem = 'Add the house or flat number';
    if (problem == null && _city.text.trim().isEmpty) problem = 'Add the city';
    if (problem == null && _state.text.trim().isEmpty) problem = 'Add the state';
    if (problem == null && _pincode.text.trim().length != 6) problem = 'Add the 6-digit pincode';
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await context.read<PharmacyProvider>().createAddress({
        'label': _label,
        'contactName': _name.text.trim(),
        'phone': _phone.text.trim(),
        'line1': _line1.text.trim(),
        'line2': _line2.text.trim(),
        'landmark': _landmark.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'pincode': _pincode.text.trim(),
        'country': 'India',
        'isDefault': _default,
        if (_location.hasPosition)
          'location': {
            'type': 'Point',
            'coordinates': [_location.lng, _location.lat],
          },
      });
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        });
      }
    }
  }

  Widget _field(String hint, TextEditingController c, IconData icon, {TextInputType? keyboard, int? max, bool caps = true}) =>
      AppTextField(
        label: '',
        hint: hint,
        controller: c,
        icon: icon,
        keyboardType: keyboard,
        inputFormatters: max == null ? null : [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(max)],
        textCapitalization: caps ? TextCapitalization.words : TextCapitalization.none,
        margin: const EdgeInsets.only(bottom: 10),
      );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New address',
              style: AppType.sans(fontSize: AppType.heading + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final l in const ['Home', 'Work', 'Other']) ...[
                  Expanded(child: AppFilterChip(label: l, selected: _label == l, block: true, onTap: () => setState(() => _label = l))),
                  if (l != 'Other') const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _field('House / flat no., building', _line1, LucideIcons.house),
            _field('Area, street', _line2, LucideIcons.signpost),
            _field('Landmark (optional)', _landmark, LucideIcons.landmark),
            Row(
              children: [
                Expanded(child: _field('City', _city, LucideIcons.building2)),
                const SizedBox(width: 10),
                Expanded(child: _field('Pincode', _pincode, LucideIcons.hash, keyboard: TextInputType.number, max: 6, caps: false)),
              ],
            ),
            _field('State', _state, LucideIcons.map),
            Row(
              children: [
                Expanded(child: _field('Name', _name, LucideIcons.user)),
                const SizedBox(width: 10),
                Expanded(child: _field('Phone', _phone, LucideIcons.phone, keyboard: TextInputType.phone, max: 10, caps: false)),
              ],
            ),
            AppSwitchRow(
              label: 'Use as default address',
              value: _default,
              onChanged: (v) => setState(() => _default = v),
              margin: EdgeInsets.zero,
            ),
            if (_error != null) ...[const SizedBox(height: 8), AuthNote.error(_error!)],
            const SizedBox(height: 14),
            AppButton(label: 'Save address', loading: _busy, onPressed: _save),
          ],
        ),
      ),
    ),
  );
}
