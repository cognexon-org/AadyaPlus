import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/auth_parts.dart';
import '../../features/onboarding/onboarding_widgets.dart';
import '../../providers/auth_provider.dart';

/// Create a patient account. Arriving from the code screen, the mobile
/// number is already verified and locked; otherwise it's typed here.
class RegisterScreen extends StatefulWidget {
  final String? verifiedPhone;
  final String? verificationToken;
  const RegisterScreen({super.key, this.verifiedPhone, this.verificationToken});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  late final _phone = TextEditingController(text: _localPhone);
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;
  String? _field; // which field the error is about
  int _shake = 0;

  bool get _verified => widget.verificationToken != null;

  String get _localPhone {
    final p = (widget.verifiedPhone ?? '').replaceAll(RegExp(r'\D'), '');
    return p.length > 10 ? p.substring(p.length - 10) : p;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fail(String message, [String? field]) => setState(() {
    _error = message;
    _field = field;
    _shake++;
  });

  Future<void> _create() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    if (name.length < 2) return _fail('Enter your full name', 'name');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      return _fail('Enter a valid email address', 'email');
    }
    if (phone.length != 10) {
      return _fail('Enter your 10-digit mobile number', 'phone');
    }
    if (_password.text.length < 6) {
      return _fail('Use at least 6 characters for your password', 'password');
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _field = null;
    });
    try {
      await context.read<AuthProvider>().register(
        name,
        email,
        _password.text,
        phone,
        verificationToken: widget.verificationToken,
      );
      if (!mounted) return;
      // Signed in: the app behind moves on to finishing the profile.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) _fail(authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _errorFor(String field) => _field == field ? '' : null;

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      minHeroHeight: authHeroHeight(context),
      hero: const IllustratedHero(
        illustration: Illustrations.register,
        
      ),
      topBar: OnboardingBack(onPressed: () => Navigator.of(context).maybePop()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppEntrance(
                child: AuthHeading(
                  title: 'Create your account',
                  subtitleText: _verified
                      ? 'Your number is verified. A few details and you’re in.'
                      : 'It takes a minute. Your details stay private.',
                ),
              ),
              const SizedBox(height: 18),
              AppEntrance(
                index: 1,
                child: ShakeOnChange(
                  trigger: _shake,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: '',
                        hint: 'Full name',
                        controller: _name,
                        icon: LucideIcons.user,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        errorText: _errorFor('name'),
                        margin: const EdgeInsets.only(bottom: 10),
                      ),
                      AppTextField(
                        label: '',
                        hint: 'Email address',
                        controller: _email,
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        errorText: _errorFor('email'),
                        margin: const EdgeInsets.only(bottom: 10),
                      ),
                      if (_verified)
                        _VerifiedPhone(phone: _phone.text)
                      else
                        PhoneField(controller: _phone),
                      const SizedBox(height: 10),
                      AppTextField(
                        label: '',
                        hint: 'Create a password',
                        controller: _password,
                        icon: LucideIcons.lockKeyhole,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) => _create(),
                        errorText: _errorFor('password'),
                        margin: EdgeInsets.zero,
                        trailing: IconButton(
                          tooltip: _hidePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                        ),
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
                        padding: const EdgeInsets.only(top: 12),
                        child: AuthNote.error(
                          _error!,
                          onClose: () => setState(() {
                            _error = null;
                            _field = null;
                          }),
                        ),
                      ),
              ),
              const SizedBox(height: 18),
              AppEntrance(
                index: 2,
                child: AppButton(
                  label: 'Create account',
                  loading: _busy,
                  onPressed: _create,
                ),
              ),
              const SizedBox(height: 10),
              AppEntrance(
                index: 3,
                child: Text(
                  'By continuing you agree to the terms of use and privacy policy.',
                  textAlign: TextAlign.center,
                  style: AppType.sans(
                    fontSize: AppType.caption,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              if (!_verified)
                AuthFootLink(
                  question: 'Have an account?',
                  action: 'Sign in',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifiedPhone extends StatelessWidget {
  final String phone;
  const _VerifiedPhone({required this.phone});

  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(LucideIcons.smartphone, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Text(
          '+91 $phone',
          style: AppType.sans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        AppStatusPill(
          text: 'Verified',
          icon: LucideIcons.badgeCheck,
          color: AppColors.health,
          background: AppColors.health.withValues(alpha: 0.1),
        ),
      ],
    ),
  );
}
