import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// The app's accent colour, read by the kit's buttons, fields, chips,
/// switches and nav bar from the nearest [ModuleTheme].
///
/// The whole patient app runs on the Aadya sky blue ([brand]). Each service
/// also has an accent — the same one its professionals see in the pro app —
/// used for that service's tiles, headers and illustrations, so a patient
/// learns "teal is doctors, plum is lab tests" across the app. Hues sit far
/// apart on the wheel, and none is red or amber: those stay reserved for
/// errors and warnings.
@immutable
class ModuleAccent {
  /// Buttons, focus rings, icons, selected states.
  final Color color;

  /// [color] at ~20% on white — selected surfaces, badges, tracks.
  final Color light;

  /// [color] at ~8% on white — tinted panels.
  final Color veryLight;

  const ModuleAccent({
    required this.color,
    required this.light,
    required this.veryLight,
  });

  ModuleAccent.from(this.color)
    : light = Color.alphaBlend(
        color.withValues(alpha: 0.2),
        const Color(0xFFFFFFFF),
      ),
      veryLight = Color.alphaBlend(
        color.withValues(alpha: 0.08),
        const Color(0xFFFFFFFF),
      );

  /// Aadya sky blue — the app itself.
  static const brand = ModuleAccent(
    color: AppColors.brand,
    light: AppColors.brandLight,
    veryLight: AppColors.brandVeryLight,
  );

  /// Doctors — clinical teal.
  static final doctor = ModuleAccent.from(const Color(0xFF0E8A8A));

  /// Physiotherapy — energetic coral.
  static final physio = ModuleAccent.from(const Color(0xFFE8572A));

  /// Lab tests — plum.
  static final lab = ModuleAccent.from(const Color(0xFF9B2FAE));

  /// Pharmacy — green.
  static final pharmacy = ModuleAccent.from(const Color(0xFF00A651));

  /// The nearest accent; the brand blue when none is set.
  static ModuleAccent of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ModuleTheme>()?.accent ??
      brand;
}

/// Sets the accent for everything below it.
class ModuleTheme extends InheritedWidget {
  final ModuleAccent accent;

  const ModuleTheme({super.key, required this.accent, required super.child});

  @override
  bool updateShouldNotify(ModuleTheme old) => old.accent.color != accent.color;
}
