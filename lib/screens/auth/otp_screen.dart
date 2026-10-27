import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/auth_parts.dart';
import '../../features/onboarding/onboarding_widgets.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

/// Enter the texted code. A known number is signed straight in; a new one
/// goes on to create an account with that number already verified.
class OtpScreen extends StatefulWidget {
  final OtpChallenge challenge;
  const OtpScreen({super.key, required this.challenge});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _length = 6;
  final _code = TextEditingController();
  final _focus = FocusNode();
  late OtpChallenge _challenge = widget.challenge;
  Timer? _timer;
  int _wait = 0;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _notice;
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    _startCooldown(_challenge.resendAfter);
    _code.addListener(_onCode);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCooldown(Duration d) {
    _timer?.cancel();
    setState(() => _wait = d.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = (_wait - 1).clamp(0, 999));
      if (_wait == 0) t.cancel();
    });
  }

  void _onCode() {
    if (_error != null) setState(() => _error = null);
    if (_code.text.length == _length && !_busy) _verify();
  }

  Future<void> _verify() async {
    if (_code.text.length != _length) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await context.read<AuthProvider>().verifyOtp(
        _challenge.phone,
        _code.text,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final nav = Navigator.of(context);
      if (token == null) {
        // Signed in: the app behind takes over.
        nav.popUntil((r) => r.isFirst);
      } else {
        nav.pushReplacement(
          AppPageRoute(
            builder: (_) => RegisterScreen(
              verifiedPhone: _challenge.phone,
              verificationToken: token,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _error = authMessage(e);
        _shake++;
        _code.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final next = await context.read<AuthProvider>().sendOtp(_challenge.phone);
      if (!mounted) return;
      _challenge = next;
      _code.clear();
      _startCooldown(next.resendAfter);
      setState(() => _notice = 'A new code is on its way');
    } catch (e) {
      if (mounted) setState(() => _error = authMessage(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String get _prettyPhone {
    final p = _challenge.phone.replaceAll(RegExp(r'\D'), '');
    final local = p.length > 10 ? p.substring(p.length - 10) : p;
    if (local.length != 10) return _challenge.phone;
    return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      minHeroHeight: authHeroHeight(context),
      hero: const IllustratedHero(
        illustration: Illustrations.otp,
        
      ),
      topBar: OnboardingBack(onPressed: () => Navigator.of(context).maybePop()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppEntrance(
              child: AuthHeading(
                title: 'Enter the code',
                subtitle: Text.rich(
                  TextSpan(
                    style: AppType.sans(
                      fontSize: AppType.body,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      const TextSpan(text: 'Sent by SMS to '),
                      TextSpan(
                        text: _prettyPhone,
                        style: AppType.sans(
                          fontSize: AppType.body,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textStrong,
                        ),
                      ),
                      const TextSpan(text: '  '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Text(
                            'Change',
                            style: AppType.sans(
                              fontSize: AppType.body,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            AppEntrance(
              index: 1,
              child: ShakeOnChange(
                trigger: _shake,
                child: OtpBoxes(
                  controller: _code,
                  focusNode: _focus,
                  error: _error != null,
                  length: _length,
                ),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.enter,
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AuthNote.error(_error!),
                    )
                  : _notice != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AuthNote.info(
                        _notice!,
                        onClose: () => setState(() => _notice = null),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 18),
            AppEntrance(
              index: 2,
              child: ListenableBuilder(
                listenable: _code,
                builder: (_, _) => AppButton(
                  label: 'Verify',
                  icon: LucideIcons.shieldCheck,
                  loading: _busy,
                  onPressed: _code.text.length == _length ? _verify : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            AppEntrance(
              index: 3,
              child: Center(
                child: _wait > 0
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Resend code in 0:${_wait.toString().padLeft(2, '0')}',
                          style: AppType.sans(
                            fontSize: AppType.body,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      )
                    : AuthFootLink(
                        question: 'Didn’t get it?',
                        action: _resending ? 'Sending…' : 'Resend code',
                        onTap: _resending ? null : _resend,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
