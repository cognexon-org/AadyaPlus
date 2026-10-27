import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/auth_parts.dart';
import '../../features/onboarding/onboarding_widgets.dart';
import '../../providers/auth_provider.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

/// Sign in, on one fixed page: a mobile number (a code is texted) by
/// default, or email and password.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  int _method = 0; // 0 mobile, 1 email
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;
  int _shake = 0;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fail(String message) => setState(() {
    _error = message;
    _shake++;
  });

  Future<void> _continueWithPhone() async {
    final phone = _phone.text.trim();
    if (phone.length != 10) {
      _fail('Enter your 10-digit mobile number');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await context.read<AuthProvider>().sendOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        AppPageRoute(builder: (_) => OtpScreen(challenge: challenge)),
      );
    } catch (e) {
      if (mounted) _fail(authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.isEmpty) {
      _fail('Enter your email and password');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(email, _password.text);
    } catch (e) {
      if (mounted) _fail(authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      minHeroHeight: authHeroHeight(context),
      hero: const IllustratedHero(illustration: Illustrations.login),
      topBar: const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(
          children: [
            BrandMark(size: 30, shadow: false),
            SizedBox(width: 8),
            Wordmark(size: 17),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppEntrance(
              child: AuthHeading(
                title: 'Welcome back',
                subtitleText: 'Sign in to book care, order medicines and see your reports.',
              ),
            ),
            const SizedBox(height: 20),
            AppEntrance(
              index: 1,
              child: MethodSwitch(
                labels: const ['Mobile', 'Email'],
                index: _method,
                onChanged: (i) => setState(() {
                  _method = i;
                  _error = null;
                }),
              ),
            ),
            const SizedBox(height: 16),
            AppEntrance(
              index: 2,
              child: ShakeOnChange(
                trigger: _shake,
                child: AnimatedSize(
                  duration: AppMotion.medium,
                  curve: AppMotion.enter,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: AppMotion.medium,
                    switchInCurve: AppMotion.enter,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(a),
                        child: child,
                      ),
                    ),
                    child: _method == 0 ? _mobileForm() : _emailForm(),
                  ),
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
                        onClose: () => setState(() => _error = null),
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            AppEntrance(
              index: 3,
              child: AppButton(
                label: _method == 0 ? 'Get code' : 'Sign in',
                icon: _method == 0 ? LucideIcons.messageSquareText : null,
                loading: _busy,
                onPressed: _method == 0 ? _continueWithPhone : _signInWithEmail,
              ),
            ),
            const SizedBox(height: 6),
            AppEntrance(
              index: 4,
              child: AuthFootLink(
                question: 'New to Aadya Plus?',
                action: 'Create account',
                onTap: () => Navigator.of(context).push(
                  AppPageRoute(builder: (_) => const RegisterScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileForm() => Column(
    key: const ValueKey('mobile'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PhoneField(
        controller: _phone,
        onSubmitted: (_) => _continueWithPhone(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          const Icon(
            LucideIcons.shieldCheck,
            size: 14,
            color: AppColors.health,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'We’ll text you a 6-digit code. New here? We’ll set you up.',
              style: AppType.sans(
                fontSize: AppType.caption,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _emailForm() => AutofillGroup(
    key: const ValueKey('email'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: '',
          hint: 'Email address',
          controller: _email,
          icon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          margin: const EdgeInsets.only(bottom: 10),
        ),
        AppTextField(
          label: '',
          hint: 'Password',
          controller: _password,
          icon: LucideIcons.lockKeyhole,
          obscureText: _hidePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _signInWithEmail(),
          margin: EdgeInsets.zero,
          trailing: IconButton(
            tooltip: _hidePassword ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
            icon: Icon(
              _hidePassword ? LucideIcons.eye : LucideIcons.eyeOff,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              AppPageRoute(
                builder: (_) => ForgotPasswordScreen(email: _email.text.trim()),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              'Forgot password?',
              style: AppType.sans(
                fontSize: AppType.small,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
