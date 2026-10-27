import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'app_type.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'app_colors.dart';
import 'app_accent.dart';
import 'app_motion.dart';

export 'app_accent.dart';
export 'app_motion.dart';

/// Shared visual language for every pharmacy screen, built to the App
/// Module Master UI Design System: iOS-native, restrained, information-dense.
/// One header style, one card style, one stat tile, one status pill, one
/// loading/empty state — so screens stop each reinventing their own
/// container/border/shadow combo. Every color/radius/spacing value here
/// comes from [AppColors] — never from the app-wide `AppTheme`.

/// The backend's Medicine.category enum, in one place — screens must use
/// this exact set of keys (a free-text field here would let a pharmacist
/// type a value Mongoose then rejects, since the enum is case-sensitive and
/// closed).
const kMedicineCategories = <String, String>{
  'tablet': 'Tablet',
  'capsule': 'Capsule',
  'syrup': 'Syrup',
  'injection': 'Injection',
  'cream': 'Cream',
  'ointment': 'Ointment',
  'drops': 'Drops',
  'inhaler': 'Inhaler',
  'other': 'Other',
};

const kMedicineCategoryIcons = <String, IconData>{
  'tablet': LucideIcons.pill,
  'capsule': LucideIcons.pillBottle,
  'syrup': LucideIcons.droplets,
  'injection': LucideIcons.syringe,
  'cream': LucideIcons.sparkle,
  'ointment': LucideIcons.flaskConical,
  'drops': LucideIcons.droplet,
  'inhaler': LucideIcons.sprayCan,
  'other': LucideIcons.circleHelp,
};

IconData medicineCategoryIcon(String? category) {
  return kMedicineCategoryIcons[category?.toLowerCase()] ?? LucideIcons.pill;
}

/// "Selling Price (₹)" → "Selling price (₹)". Field labels are sentence
/// case in the minimal style; words in capitals (GSTIN, UPI, MRP) are kept.
String appFieldLabel(String label) {
  final words = label.split(' ');
  return [
    for (var i = 0; i < words.length; i++)
      i == 0 || words[i].length < 2 || words[i] == words[i].toUpperCase()
          ? words[i]
          : '${words[i][0].toLowerCase()}${words[i].substring(1)}',
  ].join(' ');
}

TextStyle _inter({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.textPrimary,
  double? letterSpacing,
  double? height,
}) {
  return AppType.sans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

class AppScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _inter(
                  size: 17,
                  weight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.textStrong,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: _inter(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          // The notification bell now floats over Home only, so a trailing
          // action can sit at the edge on every screen that uses this header.
          trailing!,
        ],
      ],
    );
  }
}

/// The standard content card: white surface, 14px radius, thin neutral
/// border, one extremely subtle shadow. No gradients, no heavy elevation.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        // A border only when a caller asks for one (e.g. a warning card).
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: child,
    );
    return Padding(
      padding: margin,
      child: onTap == null
          ? card
          : AppPressable(scale: 0.985, onTap: onTap, child: card),
    );
  }
}

/// A small outline icon on a plain, single-tone rounded-square — used
/// sparingly (headers, hero cards, empty states), never as decoration on
/// every list row. Flat, one colour, no gradient, no border.
class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final bool circle;

  const AppIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
    this.iconSize = 18,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle
            ? null
            : BorderRadius.circular(AppColors.radiusSmall),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// Compact labeled metric box used in the Home 2x2 KPI grid and similar
/// summary rows. Carries an optional trend delta (e.g. "+12%").
class AppMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color color;
  final String? trend;
  final bool trendUp;

  /// Smaller value type, for a tile carrying a currency figure rather than a
  /// count. `₹12,68,500` at 22pt does not fit half a phone width.
  final bool compact;

  const AppMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppColors.brand,
    this.trend,
    this.trendUp = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _inter(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                // FittedBox rather than ellipsis: a truncated amount ("₹12,68…")
                // is worse than a smaller one, because it reads as a different
                // number.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: _inter(
                      size: compact ? 15 : 17,
                      weight: FontWeight.w700,
                      color: AppColors.textStrong,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendUp ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                        size: 11,
                        color: trendUp ? AppColors.success : AppColors.error,
                      ),
                      Text(
                        trend!,
                        style: _inter(
                          size: 10.5,
                          weight: FontWeight.w600,
                          color: trendUp ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The module's single selectable chip — the All / Low Stock row on Medicines,
/// the All / Placed / Packing row on Orders, the payment-method selector on
/// New Sale. Every one of those was its own near-identical copy; they are all
/// this now, so the selected state cannot drift between screens again.
///
/// Selected reads as an ink-dark chip with white text — a selected filter is
/// a state, not an action, so it doesn't take the module accent.
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Full-width, squarer variant for a row of equal-width options (the
  /// payment-method selector) rather than a scrolling pill row.
  final bool block;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.block = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(block ? AppColors.radiusInput : 20);
    // Colour, border and shadow all cross-fade, so moving the selection
    // reads as one chip handing over to the next rather than two snapping.
    return AppPressable(
      scale: 0.95,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.enter,
        padding: block
            ? const EdgeInsets.symmetric(vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: block ? Alignment.center : null,
        decoration: BoxDecoration(
          // Minimal style: a selected filter is a state, not an action, so it
          // is ink-dark rather than brand green; unselected is the grey panel.
          color: selected ? AppColors.textStrong : AppColors.panel,
          borderRadius: radius,
        ),
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.medium,
          style: AppType.sans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// Compact tinted status pill matching the design system's exact status
/// color table (order lifecycle, PO/transfer/return states, etc.).
class AppStatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color? background;
  final IconData? icon;

  const AppStatusPill({
    super.key,
    required this.text,
    required this.color,
    this.background,
    this.icon,
  });

  /// Builds a pill directly from a backend order-status key using the
  /// design system's exact per-status color table.
  factory AppStatusPill.status(String status, {String? label, Key? key}) {
    final (bg, fg) = AppColors.statusColors(status);
    return AppStatusPill(
      key: key,
      text: label ?? status.replaceAll('_', ' '),
      color: fg,
      background: bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: _inter(size: 11.5, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// A single skeleton block — a muted rounded rectangle used to compose
/// skeleton-loading layouts that approximate the real content shape.
/// Turns any thrown object into something worth showing a pharmacist.
///
/// A raw `'$e'` is the wrong thing to put on screen twice over: a Dio error
/// stringifies to a wall of request/response detail — which is what once
/// filled the whole screen with a Java stack trace — and a genuine server
/// message like "Batch number is required" is far more useful than either.
///
/// So: prefer what the server said, fall back to a plain sentence, and never
/// surface the exception itself.
String appErrorMessage(Object? error, {required String fallback}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final message = (data['message'] ?? data['error'])?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to respond. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return "Can't reach the server. Check your connection and try again.";
      default:
        break;
    }
  }
  return fallback;
}

final _pharmacyInr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
final _pharmacyInrPaise = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// A money figure in Indian grouping (₹12,68,500). Paise are shown only when
/// there are some — a ₹12.50 strip price must not round to ₹13, but a ₹450
/// order total should not read ₹450.00. For screens that printed raw values
/// like `₹${item['sellingPrice']}`, which gave ₹1268500 or ₹12.5.
String appRupees(dynamic value) {
  final n = num.tryParse('${value ?? ''}') ?? 0;
  return n == n.roundToDouble()
      ? _pharmacyInr.format(n)
      : _pharmacyInrPaise.format(n);
}

/// The module's error toast. Capped at three lines so a long server message
/// cannot take over the screen.
void showAppError(
  BuildContext context,
  Object? error, {
  required String fallback,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        appErrorMessage(error, fallback: fallback),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: _inter(size: 11.5, color: Colors.white),
      ),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Wraps a tree of [AppSkeletonBlock]s in one looping shimmer sweep.
///
/// The sweep is applied to the *group*, not to each block: a highlight that
/// restarts inside every individual bar reads as noise, while one pass
/// travelling across the whole placeholder reads as loading. So skeleton
/// blocks stay inert and this supplies the motion.
class AppShimmer extends StatelessWidget {
  final Widget child;

  /// Lets a caller mount the same tree without motion — for a screenshot, or
  /// when the platform reports that animations should be reduced.
  final bool enabled;

  const AppShimmer({super.key, required this.child, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1150.ms,
          // A beat between passes; a shimmer with no gap looks frantic.
          delay: 350.ms,
          color: Colors.white,
          angle: 0.35,
        );
  }
}

class AppSkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const AppSkeletonBlock({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.borderStrong,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton loading state for a list screen — a handful of card-shaped
/// placeholders instead of a full-screen spinner, so the layout doesn't
/// jump once real content arrives.
/// The page gutter skeletons sit in by default.
const appSkeletonPadding = EdgeInsets.fromLTRB(20, 8, 20, 0);

class AppListSkeleton extends StatelessWidget {
  final int count;

  /// Space around the placeholder; the page gutter by default, so it lines
  /// up with the content that replaces it.
  final EdgeInsetsGeometry padding;

  const AppListSkeleton({
    super.key,
    this.count = 5,
    this.padding = appSkeletonPadding,
  });

  /// One placeholder card: 16px padding top and bottom around a 40px block,
  /// plus the card's 12px bottom margin.
  static const _cardExtent = 84.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Inside a bounded box — an Expanded, a sized sheet tab — asking for
        // more cards than fit overflows the Column. Draw only what the space
        // allows; a placeholder has no obligation to show a particular number
        // of rows.
        final room = constraints.maxHeight - padding.vertical;
        final fits = constraints.maxHeight.isFinite
            ? (room / _cardExtent).floor().clamp(1, count)
            : count;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(padding: padding, child: _build(fits)),
        );
      },
    );
  }

  Widget _build(int count) {
    return AppShimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          count,
          (i) => AppCard(
            child: Row(
              children: [
                const AppSkeletonBlock(
                  width: 40,
                  height: 40,
                  radius: AppColors.radiusSmall,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppSkeletonBlock(width: 140, height: 13),
                      SizedBox(height: 8),
                      AppSkeletonBlock(width: 90, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder shaped like a form: a short label bar over a full-width field
/// box, repeated. Used by the edit-profile and settings screens, where a list
/// skeleton would promise rows that never arrive.
class AppFormSkeleton extends StatelessWidget {
  final int fields;
  final EdgeInsetsGeometry padding;

  const AppFormSkeleton({
    super.key,
    this.fields = 5,
    this.padding = appSkeletonPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < fields; i++) ...[
              const AppSkeletonBlock(width: 96, height: 11),
              const SizedBox(height: 7),
              const AppSkeletonBlock(height: 44, radius: AppColors.radiusInput),
              SizedBox(height: i == fields - 1 ? 0 : 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// Placeholder shaped like a detail page: a header tile with a title and
/// subtitle, a band of stat boxes, then a run of label/value rows.
class AppDetailSkeleton extends StatelessWidget {
  final int rows;
  final EdgeInsetsGeometry padding;

  const AppDetailSkeleton({
    super.key,
    this.rows = 6,
    this.padding = appSkeletonPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppSkeletonBlock(width: 52, height: 52, radius: 14),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppSkeletonBlock(width: 170, height: 16),
                      SizedBox(height: 9),
                      AppSkeletonBlock(width: 110, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: const [
                Expanded(child: AppSkeletonBlock(height: 62, radius: 14)),
                SizedBox(width: 12),
                Expanded(child: AppSkeletonBlock(height: 62, radius: 14)),
                SizedBox(width: 12),
                Expanded(child: AppSkeletonBlock(height: 62, radius: 14)),
              ],
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < rows; i++) ...[
              Row(
                children: [
                  AppSkeletonBlock(width: 84 + (i.isEven ? 26 : 0), height: 12),
                  const Spacer(),
                  AppSkeletonBlock(width: 60 + (i.isOdd ? 22 : 0), height: 12),
                ],
              ),
              SizedBox(height: i == rows - 1 ? 0 : 20),
            ],
          ],
        ),
      ),
    );
  }
}

/// Consistent branded loading state for a section too small for a skeleton
/// list (a tab, a modal, an inline refresh).
class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: ModuleAccent.of(context).color,
        ),
      ),
    );
  }
}

/// Consistent inline error banner — never surfaces raw API errors.
class AppErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.circleAlert, size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: _inter(size: 11.5, color: AppColors.error),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: _inter(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact empty-state row for embedding inside a ListView — a small
/// outline icon, a short headline, no decorative illustration.
class AppEmptyStateInline extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const AppEmptyStateInline({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppFloat(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            style: _inter(
              size: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// A labeled text field for forms — label above, 10px radius, 46-50px
/// height, green focus border. What every form in the pharmacy module uses
/// instead of a bare `TextField`.
class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final bool isNum;
  final bool isDecimal;
  final int maxLines;
  final String? hint;
  final bool required;
  final EdgeInsetsGeometry margin;

  /// Tighter type and padding, for a form long enough that the default
  /// 48px-tall field turns the screen into a scroll marathon.
  final bool dense;

  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  /// A widget at the field's right edge — e.g. a scan button.
  final Widget? trailing;

  final bool obscureText;
  final bool readOnly;

  /// Overrides the keyboard chosen from [isNum]/[isDecimal] (email, phone).
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  /// Shown under the field in red, and outlines it — for a value the user
  /// has to fix before going on.
  final String? errorText;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.isNum = false,
    this.isDecimal = false,
    this.maxLines = 1,
    this.hint,
    this.required = false,
    this.margin = const EdgeInsets.only(bottom: 16),
    this.dense = false,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.trailing,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Text(
              required ? '${appFieldLabel(label)} *' : appFieldLabel(label),
              style: _inter(
                size: dense ? 11.5 : 11.5,
                weight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          if (label.isNotEmpty) SizedBox(height: dense ? 5 : 6),
          TextField(
            controller: controller,
            maxLines: obscureText ? 1 : maxLines,
            obscureText: obscureText,
            readOnly: readOnly,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            keyboardType:
                keyboardType ??
                (isDecimal
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : isNum
                    ? TextInputType.number
                    : TextInputType.text),
            style: _inter(
              size: 13,
              color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
            ),
            cursorColor: ModuleAccent.of(context).color,
            decoration: InputDecoration(
              hintText: hint,
              errorText: errorText,
              errorMaxLines: 2,
              errorStyle: _inter(size: 11, color: AppColors.error),
              hintStyle: _inter(
                size: dense ? 12.5 : 12.5,
                color: AppColors.textTertiary,
              ),
              isDense: true,
              filled: true,
              fillColor: AppColors.panel,
              suffixIcon: trailing,
              contentPadding: EdgeInsets.symmetric(
                horizontal: dense ? 12 : 14,
                vertical: maxLines > 1 ? (dense ? 10 : 12) : (dense ? 10 : 12),
              ),
              prefixIconConstraints: dense
                  ? const BoxConstraints(minWidth: 38, minHeight: 0)
                  : null,
              prefixIcon: icon == null
                  ? null
                  : Icon(
                      icon,
                      size: dense ? 16 : 18,
                      color: AppColors.textTertiary,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusInput),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusInput),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusInput),
                borderSide: BorderSide(
                  color: ModuleAccent.of(context).color,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusInput),
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusInput),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labeled dropdown matching [AppTextField]'s look.
class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final EdgeInsetsGeometry margin;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appFieldLabel(label),
            style: _inter(
              size: 11.5,
              weight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            initialValue: value,
            // Fills the field so a long item ellipsises instead of
            // overflowing a half-width field.
            isExpanded: true,
            items: items,
            onChanged: onChanged,
            style: _inter(size: 13, color: AppColors.textPrimary),
            icon: const Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: AppColors.textTertiary,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.panel,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              prefixIcon: icon == null
                  ? null
                  : Icon(icon, size: 18, color: AppColors.textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusInput),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusInput),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusInput),
                borderSide: BorderSide(
                  color: ModuleAccent.of(context).color,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable switch row — replaces bare Material `SwitchListTile`.
/// The module's switch, sized down from Material's default.
///
/// A stock [Switch] is ~59x48 including its 48dp tap target, which next to
/// 13.5pt row text reads as the heaviest thing on the screen. Two changes
/// shrink it: `shrinkWrap` drops the enforced 48dp box, and the scale takes
/// the control itself down. The tap target is not a concern here because the
/// whole row is the target — [AppSwitchRow] wraps it in an InkWell, and
/// the coupon list row does the same.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.78,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: ModuleAccent.of(context).color,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: AppColors.borderStrong,
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class AppSwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final EdgeInsetsGeometry margin;

  /// When false the row dims and stops responding — for a setting that only
  /// applies while some parent setting is on. It stays visible rather than
  /// disappearing, so the list does not reflow as you toggle the parent.
  final bool enabled;

  const AppSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.margin = const EdgeInsets.only(bottom: 4),
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppColors.radiusSmall),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppColors.radiusSmall),
          onTap: enabled ? () => onChanged(!value) : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appFieldLabel(label),
                          style: _inter(
                            size: 13,
                            weight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: _inter(
                              size: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  AppSwitch(
                    value: value,
                    onChanged: enabled ? onChanged : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A search field styled to match the rest of the pharmacy module.
/// A tappable field-styled row that launches a date/time picker, matching
/// [AppTextField]'s label/field rhythm instead of a bare `ListTile`.
class AppPickerField extends StatelessWidget {
  final String label;
  final String valueText;
  final IconData icon;
  final VoidCallback onTap;
  final bool required;
  final EdgeInsetsGeometry margin;

  const AppPickerField({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
    this.icon = LucideIcons.calendar,
    this.required = false,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '${appFieldLabel(label)} *' : appFieldLabel(label),
            style: _inter(
              size: 11.5,
              weight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppColors.radiusInput),
              onTap: onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(AppColors.radiusInput),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.textTertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        valueText,
                        style: _inter(size: 13, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onSubmitted;
  final VoidCallback? onRefresh;
  final ValueChanged<String>? onChanged;

  /// Shows a barcode button inside the field when set.
  final VoidCallback? onScan;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onSubmitted,
    this.onRefresh,
    this.onChanged,
    this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmitted?.call(),
      onChanged: onChanged,
      style: _inter(size: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _inter(size: 12.5, color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.panel,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        prefixIcon: const Icon(
          LucideIcons.search,
          size: 18,
          color: AppColors.textTertiary,
        ),
        suffixIcon: onScan != null
            ? IconButton(
                tooltip: 'Scan barcode',
                icon: Icon(
                  LucideIcons.scanBarcode,
                  size: 20,
                  color: ModuleAccent.of(context).color,
                ),
                onPressed: onScan,
              )
            : onRefresh == null
            ? null
            : IconButton(
                icon: const Icon(
                  LucideIcons.refreshCw,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: onRefresh,
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          borderSide: BorderSide(
            color: ModuleAccent.of(context).color,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Primary green filled button — 10px radius, 48px height, no gradient.
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool fullWidth;

  /// 40px instead of 46px — for a button inside a card or list row, where a
  /// full-height button outweighs the content around it.
  final bool compact;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.fullWidth = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: ModuleAccent.of(context).color,
        disabledBackgroundColor: ModuleAccent.of(
          context,
        ).color.withValues(alpha: 0.4),
        foregroundColor: Colors.white,
        minimumSize: Size(0, compact ? 40 : 46),
        padding: compact ? const EdgeInsets.symmetric(horizontal: 16) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusButton),
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          // The label is Flexible and ellipsises: this button is dropped into
          // fixed-width slots (the save bars use a 140px box), and an
          // unconstrained Row there overflows rather than shrinking.
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: _inter(
                      size: 13,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: child) : child;
  }
}

/// Secondary outlined button — white surface, green text/border.
class AppSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final Color? color;

  const AppSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.fullWidth = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // No colour given: the icon takes the module accent, the label stays ink.
    final color = this.color ?? ModuleAccent.of(context).color;
    final child = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: AppColors.panel,
        side: BorderSide.none,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusButton),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _inter(
                size: 13,
                weight: FontWeight.w600,
                color: this.color == null ? AppColors.textPrimary : color,
              ),
            ),
          ),
        ],
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: child) : child;
  }
}

/// Consistent floating action button — solid green fill, plain neutral
/// shadow, no gradient.
class AppFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const AppFab({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      scale: 0.94,
      onTap: onPressed,
      semanticLabel: label,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.shadowElevated,
      ),
      child: Material(
        color: ModuleAccent.of(context).color,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: _inter(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a builder's content with a rounded top sheet + drag handle, so every
/// showModalBottomSheet in the pharmacy module looks the same (used for
/// filters, branch selection, payment method, medicine selection, etc. per
/// the design system — bottom sheets are the default modal, not centered
/// dialogs).
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppColors.radiusSheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          // The keyboard's height is added to the bottom padding, so a sheet
          // containing text fields lifts above it instead of being covered by
          // it. `isScrollControlled` alone only allows the sheet to grow — it
          // does nothing about the inset.
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(child: builder(ctx)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// App-flavoured modal dialog shell — used only where a destructive
/// confirmation genuinely calls for a centered dialog rather than a bottom
/// sheet. Icon badge + title/subtitle header, scrollable content, weighted
/// action row.
class AppDialog {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData icon = LucideIcons.squarePen,
    Color? accentColor,
    required Widget content,
    required List<Widget> actions,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppColors.radiusCardLarge),
              boxShadow: AppColors.shadowModal,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        color: accentColor ?? ModuleAccent.of(ctx).color,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: _inter(
                                size: 15,
                                weight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: _inter(
                                  size: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SingleChildScrollView(child: content),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i != 0) const SizedBox(width: 10),
                        Expanded(child: actions[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget cancelButton(
    BuildContext context, {
    String label = 'Cancel',
    VoidCallback? onPressed,
  }) {
    return AppSecondaryButton(
      label: label,
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
    );
  }

  static Widget primaryButton(
    String label,
    VoidCallback? onPressed, {
    Color? color,
  }) {
    return Builder(
      builder: (context) => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? ModuleAccent.of(context).color,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusButton),
          ),
        ),
        child: Text(
          label,
          style: _inter(size: 13, weight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  /// The one case the design system allows a centered dialog for:
  /// destructive confirmations (deactivate, delete, discard). Every other
  /// modal in the module should use [showAppSheet] instead.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = LucideIcons.triangleAlert,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = true,
  }) async {
    final color = destructive
        ? AppColors.error
        : ModuleAccent.of(context).color;
    final result = await show<bool>(
      context,
      title: title,
      icon: icon,
      accentColor: color,
      content: Text(
        message,
        style: _inter(size: 13, color: AppColors.textSecondary, height: 1.5),
      ),
      actions: [
        cancelButton(
          context,
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        primaryButton(
          confirmLabel,
          () => Navigator.of(context).pop(true),
          color: color,
        ),
      ],
    );
    return result == true;
  }
}

/// Forces typed text to uppercase as it is entered — for GSTINs, drug licence
/// numbers and other codes the server stores in capitals.
class AppUpperCaseFormatter extends TextInputFormatter {
  const AppUpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

// ═══════════════════════ Minimal section primitives ═══════════════════════

/// "DELIVERY ADDRESS" → "Delivery address". Screens still pass the old
/// upper-case labels; the minimal style sets section titles in sentence case.
String appSentenceCase(String text) {
  final t = text.trim();
  if (t.isEmpty) return t;
  if (t != t.toUpperCase()) return t;
  final lower = t.toLowerCase();
  return '${lower[0].toUpperCase()}${lower.substring(1)}'
      .replaceAll('gstin', 'GSTIN')
      .replaceAll('upi', 'UPI')
      .replaceAll(' rx', ' Rx');
}

/// A section heading above a [AppGroup]: 15pt bold ink, optional green
/// text action on the right.
class AppSectionTitle extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const AppSectionTitle(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
    // Flush left, so titles line up with form-field labels below them.
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            appSentenceCase(text),
            style: _inter(
              size: 13,
              weight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                action!,
                style: _inter(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: ModuleAccent.of(context).color,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The minimal style's grouped panel: grey fill, 14px corners, no border or
/// shadow. Pass rows and hairlines as children.
class AppGroup extends StatelessWidget {
  final List<Widget> children;
  const AppGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

/// Divider between rows inside a [AppGroup] — white on the grey panel,
/// inset from the left like an iOS grouped list.
class AppHairline extends StatelessWidget {
  const AppHairline({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.only(left: 16),
    color: AppColors.bg,
  );
}

/// "You're offline" strip, shown above the pharmacy nav bar while the server
/// cannot be reached. The screens keep showing what they last loaded; the
/// orders check retries every 20 seconds and clears this on its own.
class AppOfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const AppOfflineBanner({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.textStrong,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(LucideIcons.wifiOff, size: 16, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You're offline · showing the last loaded data",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _inter(
                size: 12.5,
                weight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              'Retry',
              style: _inter(
                size: 12.5,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
