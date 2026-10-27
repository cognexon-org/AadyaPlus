import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/auth_parts.dart';
import '../../features/onboarding/onboarding_widgets.dart';
import '../../providers/auth_provider.dart';

/// The last step of sign-up: date of birth and gender, which doctors and
/// labs need before anything can be booked.
class CompletePatientProfileScreen extends StatefulWidget {
  const CompletePatientProfileScreen({super.key});

  @override
  State<CompletePatientProfileScreen> createState() =>
      _CompletePatientProfileScreenState();
}

class _CompletePatientProfileScreenState
    extends State<CompletePatientProfileScreen> {
  DateTime? _dateOfBirth;
  String? _gender;
  bool _busy = false;
  String? _error;
  int _shake = 0;

  static const _genders = [
    ('female', 'Female'),
    ('male', 'Male'),
    ('other', 'Other'),
    ('prefer_not_to_say', 'Prefer not to say'),
  ];

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Date of birth',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = picked;
        _error = null;
      });
    }
  }

  int? get _age {
    final dob = _dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _submit() async {
    if (_dateOfBirth == null || _gender == null) {
      setState(() {
        _error = _dateOfBirth == null
            ? 'Add your date of birth'
            : 'Choose how you’d like to be identified';
        _shake++;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().completePatientProfile(
        dateOfBirth: _dateOfBirth!,
        gender: _gender!,
      );
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = authMessage(e);
          _shake++;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final first = (auth.user?.name ?? '').trim().split(RegExp(r'\s+')).first;
    return AuthLayout(
      minHeroHeight: authHeroHeight(context),
      hero: const IllustratedHero(
        illustration: Illustrations.profileSetup,
        
      ),
      topBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
        child: Row(
          children: [
            const BrandMark(size: 30, shadow: false),
            const Spacer(),
            TextButton(
              onPressed: auth.isLoading ? null : auth.logout,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppEntrance(
              child: AuthHeading(
                title: first.isEmpty ? 'Almost there' : 'Almost there, $first',
                subtitleText:
                    'Doctors and labs need these two details before your first booking.',
              ),
            ),
            const SizedBox(height: 20),
            AppEntrance(
              index: 1,
              child: ShakeOnChange(
                trigger: _shake,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Date of birth'),
                    AppPressable(
                      onTap: _pickDate,
                      semanticLabel: 'Choose date of birth',
                      child: AnimatedContainer(
                        duration: AppMotion.fast,
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _dateOfBirth == null
                              ? AppColors.panel
                              : AppColors.brandVeryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.cake,
                              size: 18,
                              color: _dateOfBirth == null
                                  ? AppColors.textTertiary
                                  : AppColors.brand,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _dateOfBirth == null
                                    ? 'Choose a date'
                                    : DateFormat('d MMMM y').format(_dateOfBirth!),
                                style: AppType.sans(
                                  fontSize: 15,
                                  fontWeight: _dateOfBirth == null
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                  color: _dateOfBirth == null
                                      ? AppColors.textTertiary
                                      : AppColors.textStrong,
                                ),
                              ),
                            ),
                            if (_age != null)
                              Text(
                                '$_age yrs',
                                style: AppType.sans(
                                  fontSize: AppType.small,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brand,
                                ),
                              )
                            else
                              const Icon(
                                LucideIcons.calendarDays,
                                size: 18,
                                color: AppColors.textTertiary,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _label('Gender'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (value, label) in _genders)
                          _Choice(
                            label: label,
                            selected: _gender == value,
                            onTap: () => setState(() {
                              _gender = value;
                              _error = null;
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.enter,
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: AuthNote.error(_error!),
                    ),
            ),
            const SizedBox(height: 22),
            AppEntrance(
              index: 2,
              child: AppButton(
                label: 'Continue',
                icon: LucideIcons.arrowRight,
                loading: _busy,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.lock, size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  'Only your care providers see this',
                  style: AppType.sans(
                    fontSize: AppType.caption,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: AppType.sans(
        fontSize: AppType.small,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: AppPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandVeryLight : AppColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.brand : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: AppMotion.fast,
              child: selected
                  ? const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(LucideIcons.check, size: 15, color: AppColors.brand),
                    )
                  : const SizedBox.shrink(),
            ),
            Text(
              label,
              style: AppType.sans(
                fontSize: AppType.body,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.brandDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
