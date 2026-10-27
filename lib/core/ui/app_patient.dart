import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_accent.dart';
import 'app_colors.dart';
import 'app_illustration.dart';
import 'app_kit.dart';
import 'app_motion.dart';
import 'app_type.dart';

// The patient app's shared pieces on top of the kit: one way to name and
// colour a status, one avatar, one section header, one empty state.

/// How a backend status reads to a patient: plain words, one tone.
class PatientStatus {
  final String label;
  final Color color;
  final IconData icon;
  const PatientStatus(this.label, this.color, this.icon);

  Color get background => Color.alphaBlend(
    color.withValues(alpha: 0.1),
    Colors.white,
  );

  static const _blue = Color(0xFF2563EB);
  static const _violet = Color(0xFF7C3AED);
  static const _neutral = AppColors.textSecondary;

  /// Any appointment, lab order, medicine order, prescription or payment
  /// status the backend sends.
  static PatientStatus of(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      // Waiting on someone else.
      case 'pending':
      case 'requested':
        return const PatientStatus('Awaiting confirmation', AppColors.warning, LucideIcons.hourglass);
      case 'payment_pending':
        return const PatientStatus('Payment due', AppColors.warning, LucideIcons.creditCard);
      case 'prescription_review':
      case 'pending_review':
        return const PatientStatus('Prescription in review', AppColors.warning, LucideIcons.fileSearch);
      case 'cancel_requested':
        return const PatientStatus('Cancelling', AppColors.warning, LucideIcons.hourglass);
      case 'refund_pending':
        return const PatientStatus('Refund in progress', AppColors.warning, LucideIcons.rotateCcw);
      // Going ahead.
      case 'confirmed':
      case 'accepted':
      case 'scheduled':
      case 'approved':
        return const PatientStatus('Confirmed', AppColors.brand, LucideIcons.circleCheck);
      case 'rescheduled':
        return const PatientStatus('Rescheduled', AppColors.brand, LucideIcons.calendarClock);
      case 'placed':
        return const PatientStatus('Order placed', AppColors.brand, LucideIcons.receipt);
      case 'packing':
      case 'ready_to_ship':
        return const PatientStatus('Being packed', _blue, LucideIcons.package);
      case 'shipped':
        return const PatientStatus('Shipped', _violet, LucideIcons.truck);
      case 'out_for_delivery':
        return const PatientStatus('Out for delivery', _violet, LucideIcons.bike);
      case 'in_progress':
        return const PatientStatus('In progress', _blue, LucideIcons.activity);
      case 'sample_collected':
        return const PatientStatus('Sample collected', _blue, LucideIcons.testTube);
      case 'processing':
      case 'ready_for_review':
        return const PatientStatus('Testing in lab', _violet, LucideIcons.flaskConical);
      // Done.
      case 'completed':
        return const PatientStatus('Completed', AppColors.health, LucideIcons.circleCheckBig);
      case 'delivered':
        return const PatientStatus('Delivered', AppColors.health, LucideIcons.packageCheck);
      case 'paid':
        return const PatientStatus('Paid', AppColors.health, LucideIcons.badgeCheck);
      case 'issued':
        return const PatientStatus('Active', AppColors.health, LucideIcons.fileCheck);
      case 'refunded':
      case 'partially_refunded':
        return const PatientStatus('Refunded', _neutral, LucideIcons.rotateCcw);
      case 'superseded':
        return const PatientStatus('Replaced', _neutral, LucideIcons.fileClock);
      // Stopped.
      case 'cancelled':
        return const PatientStatus('Cancelled', AppColors.error, LucideIcons.circleX);
      case 'rejected':
        return const PatientStatus('Declined', AppColors.error, LucideIcons.circleX);
      case 'no_show':
        return const PatientStatus('Missed', AppColors.error, LucideIcons.circleSlash);
      case 'returned':
        return const PatientStatus('Returned', _neutral, LucideIcons.undo2);
      case 'failed':
        return const PatientStatus('Failed', AppColors.error, LucideIcons.circleAlert);
      case 'expired':
        return const PatientStatus('Expired', _neutral, LucideIcons.clock);
      default:
        return PatientStatus(sentenceCase(raw ?? ''), _neutral, LucideIcons.circleDot);
    }
  }

  Widget pill({bool icon = true}) => AppStatusPill(
    text: label,
    color: color,
    background: background,
    icon: icon ? this.icon : null,
  );
}

/// "out_for_delivery" → "Out for delivery".
String sentenceCase(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1).toLowerCase();
}

/// A person's photo, or their initials on a tint of [color] when there is
/// no photo (or it fails to load).
class AppAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final Color? color;
  final double? radius;
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 44,
    this.color,
    this.radius,
  });

  String get _initials {
    final parts = name
        .replaceFirst(RegExp(r'^(dr\.?|mr\.?|ms\.?|mrs\.?)\s+', caseSensitive: false), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tone = color ?? ModuleAccent.of(context).color;
    final r = BorderRadius.circular(radius ?? size / 2);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(tone.withValues(alpha: 0.12), Colors.white),
        borderRadius: r,
      ),
      child: Text(
        _initials,
        style: AppType.sans(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: tone,
        ),
      ),
    );
    final url = imageUrl?.trim() ?? '';
    if (!url.startsWith('http')) return fallback;
    return ClipRRect(
      borderRadius: r,
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

/// A section title with an optional "See all" style action.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  const AppSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 12, 10),
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppType.sans(
              fontSize: AppType.title + 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.textStrong,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: ModuleAccent.of(context).color,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              textStyle: AppType.sans(
                fontSize: AppType.small,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(action!),
          ),
      ],
    ),
  );
}

/// An empty or error state with one of the bundled illustrations.
class AppEmptyState extends StatelessWidget {
  final String illustration;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double illustrationHeight;
  const AppEmptyState({
    super.key,
    required this.illustration,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.illustrationHeight = 150,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    child: AppEntrance(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIllustration(illustration, height: illustrationHeight, float: true),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.sans(
              fontSize: AppType.heading,
              fontWeight: FontWeight.w800,
              color: AppColors.textStrong,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppType.sans(
                fontSize: AppType.body,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              fullWidth: false,
            ),
          ],
        ],
      ),
    ),
  );
}

/// The standard top bar of a pushed screen: a title (and optional line
/// under it) on white, with actions on the right.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showBack;
  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
    this.showBack = true,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(60 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 60,
    automaticallyImplyLeading: showBack,
    leading: showBack && Navigator.of(context).canPop()
        ? IconButton(
            tooltip: 'Back',
            icon: const Icon(LucideIcons.arrowLeft, size: 22),
            onPressed: () => Navigator.of(context).maybePop(),
          )
        : null,
    titleSpacing: showBack && Navigator.of(context).canPop() ? 0 : 20,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppType.sans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.textStrong,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: AppType.sans(
              fontSize: AppType.caption,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    ),
    actions: [...?actions, const SizedBox(width: 8)],
    bottom: bottom,
  );
}

/// Reads a value the backend may send as a number or a string.
double asDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

/// A map's `_id` (or `id`) as a string.
String idOf(dynamic m) => m is Map ? (m['_id'] ?? m['id'] ?? '').toString() : '';

/// A populated reference as a map, or an empty map when it wasn't populated.
Map<String, dynamic> mapOf(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// A list of maps, skipping anything that isn't one.
List<Map<String, dynamic>> mapsOf(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];
