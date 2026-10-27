import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/auth_parts.dart';
import '../../features/onboarding/onboarding_widgets.dart';
import '../../providers/auth_provider.dart';

/// Ask for a password reset link by email, then show that it's on its way.
class ForgotPasswordScreen extends StatefulWidget {
  final String email;
  const ForgotPasswordScreen({super.key, this.email = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false;
  bool _sent = false;
  String? _error;
  int _shake = 0;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _error = 'Enter the email you signed up with';
        _shake++;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().forgotPassword(email);
      if (mounted) setState(() => _sent = true);
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
    return AuthLayout(
      minHeroHeight: authHeroHeight(context),
      hero: IllustratedHero(
        illustration: _sent ? Illustrations.success : Illustrations.forgotPassword,
        
      ),
      topBar: OnboardingBack(onPressed: () => Navigator.of(context).maybePop()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
        child: AnimatedSwitcher(
          duration: AppMotion.medium,
          switchInCurve: AppMotion.enter,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(a),
              child: child,
            ),
          ),
          child: _sent ? _sentView() : _form(),
        ),
      ),
    );
  }

  Widget _form() => Column(
    key: const ValueKey('form'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AppEntrance(
        child: AuthHeading(
          title: 'Reset your password',
          subtitleText: 'Enter your account’s email and we’ll send you a link to set a new password.',
        ),
      ),
      const SizedBox(height: 20),
      AppEntrance(
        index: 1,
        child: ShakeOnChange(
          trigger: _shake,
          child: AppTextField(
            label: '',
            hint: 'Email address',
            controller: _email,
            icon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _send(),
            margin: EdgeInsets.zero,
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
                child: AuthNote.error(_error!),
              ),
      ),
      const SizedBox(height: 18),
      AppEntrance(
        index: 2,
        child: AppButton(
          label: 'Send reset link',
          icon: LucideIcons.send,
          loading: _busy,
          onPressed: _send,
        ),
      ),
    ],
  );

  Widget _sentView() => Column(
    key: const ValueKey('sent'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AuthHeading(
        title: 'Check your email',
        subtitle: Text.rich(
          TextSpan(
            style: AppType.sans(
              fontSize: AppType.body,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
            children: [
              const TextSpan(text: 'If an account uses '),
              TextSpan(
                text: _email.text.trim(),
                style: AppType.sans(
                  fontSize: AppType.body,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textStrong,
                ),
              ),
              const TextSpan(
                text: ', a reset link is on its way.',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const AuthNote.info(
        'Not there? Check spam, or sign in with your mobile number instead.',
      ),
      const SizedBox(height: 18),
      AppButton(
        label: 'Back to sign in',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      AuthFootLink(
        question: 'Wrong email?',
        action: 'Try again',
        onTap: () => setState(() => _sent = false),
      ),
    ],
  );
}
