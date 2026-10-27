import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/app_ui.dart';

/// The heading at the top of a sign-in sheet.
class AuthHeading extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final String? subtitleText;
  const AuthHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleText,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: AppType.sans(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AppColors.textStrong,
        ),
      ),
      const SizedBox(height: 4),
      subtitle ??
          Text(
            subtitleText ?? '',
            style: AppType.sans(
              fontSize: AppType.body,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
    ],
  );
}

/// An Indian mobile number field: a fixed +91 prefix, ten digits.
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool readOnly;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  const PhoneField({
    super.key,
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    this.readOnly = false,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ModuleAccent.of(context).color;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      cursorColor: accent,
      style: AppType.sans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: readOnly ? AppColors.textSecondary : AppColors.textStrong,
      ),
      decoration: InputDecoration(
        hintText: 'Mobile number',
        hintStyle: AppType.sans(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textTertiary,
        ),
        filled: true,
        fillColor: AppColors.panel,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+91',
                style: AppType.sans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 20, color: AppColors.borderStrong),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }
}

/// Six boxes over one invisible field, so the keyboard, paste and SMS
/// autofill all work as for a normal text field. Each digit pops in.
class OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool error;
  final int length;
  const OtpBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    this.error = false,
    this.length = 6,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ModuleAccent.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final digits = controller.text;
        return GestureDetector(
          onTap: focusNode.requestFocus,
          child: Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: AppMotion.fast,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i < digits.length
                              ? accent.veryLight
                              : AppColors.panel,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            width: 1.5,
                            color: error
                                ? AppColors.error
                                : (i == digits.length && focusNode.hasFocus)
                                ? accent.color
                                : Colors.transparent,
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (c, a) => ScaleTransition(
                            scale: Tween(begin: 0.5, end: 1.0).animate(
                              CurvedAnimation(
                                parent: a,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                            child: FadeTransition(opacity: a, child: c),
                          ),
                          child: Text(
                            i < digits.length ? digits[i] : '',
                            key: ValueKey(
                              '$i-${i < digits.length ? digits[i] : ''}',
                            ),
                            style: AppType.sans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textStrong,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(length),
                    ],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shakes its child sideways once each time [trigger] changes.
class ShakeOnChange extends StatelessWidget {
  final int trigger;
  final Widget child;
  const ShakeOnChange({super.key, required this.trigger, required this.child});

  @override
  Widget build(BuildContext context) {
    if (trigger == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (context, t, c) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 6) * 10 * (1 - t), 0),
        child: c,
      ),
      child: child,
    );
  }
}

/// A two-way switch between sign-in methods, with a sliding thumb.
class MethodSwitch extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const MethodSwitch({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(14),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth / labels.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: w * index,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == index,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (i == index) return;
                          HapticFeedback.selectionClick();
                          onChanged(i);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: AppMotion.fast,
                            style: AppType.sans(
                              fontSize: AppType.body,
                              fontWeight: FontWeight.w700,
                              color: i == index
                                  ? AppColors.textStrong
                                  : AppColors.textSecondary,
                            ),
                            child: Text(labels[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

/// "Question? Action" at the foot of a sign-in sheet.
class AuthFootLink extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback? onTap;
  const AuthFootLink({
    super.key,
    required this.question,
    required this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$question ',
              style: AppType.sans(
                fontSize: AppType.body,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            TextSpan(
              text: action,
              style: AppType.sans(
                fontSize: AppType.body,
                fontWeight: FontWeight.w700,
                color: ModuleAccent.of(context).color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Turns an exception into the line shown to the user.
String authMessage(Object error) {
  final text = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  if (text.contains('SocketException') ||
      text.contains('TimeoutException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection')) {
    return 'Couldn’t reach Aadya Plus. Check your connection and try again.';
  }
  return text;
}

/// The least height a sign-in hero gets on this device; it grows into
/// whatever the form leaves free.
double authHeroHeight(BuildContext context) {
  final h = MediaQuery.of(context).size.height;
  return (h * 0.26).clamp(170.0, 240.0);
}
