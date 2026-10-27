import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/ui/app_ui.dart';

// ─────────────────────────── Backdrops ───────────────────────────

/// The deep sky behind the splash: the brand blue falling from a lighter
/// sky, with soft fields of light drifting across it. [bloom] (0–1) opens
/// the light up from nothing.
class SkyBackdrop extends StatefulWidget {
  final double bloom;
  const SkyBackdrop({super.key, this.bloom = 1});

  @override
  State<SkyBackdrop> createState() => _SkyBackdropState();
}

class _SkyBackdropState extends State<SkyBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _drift,
      builder: (_, _) => CustomPaint(
        painter: _SkyPainter(t: _drift.value, bloom: widget.bloom),
        size: Size.infinite,
      ),
    ),
  );
}

class _SkyPainter extends CustomPainter {
  final double t;
  final double bloom;
  const _SkyPainter({required this.t, required this.bloom});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0EA5E9), AppColors.brand, Color(0xFF075985)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    final a = t * 2 * math.pi;
    void light(Offset c, double r, Color color, double alpha) {
      final radius = r * (0.35 + 0.65 * bloom);
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha * bloom),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }

    final w = size.width;
    final h = size.height;
    light(
      Offset(w * (0.8 + 0.06 * math.sin(a)), h * (0.16 + 0.04 * math.cos(a))),
      w * 0.8,
      Colors.white,
      0.32,
    );
    light(
      Offset(w * (0.12 + 0.06 * math.cos(a)), h * (0.7 + 0.05 * math.sin(a))),
      w * 0.75,
      const Color(0xFF7DD3FC),
      0.38,
    );
    light(
      Offset(w * (0.55 + 0.08 * math.sin(a + 1.3)), h * (0.45 + 0.04 * math.cos(a))),
      w * 0.5,
      const Color(0xFF34D399),
      0.16,
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t || old.bloom != bloom;
}

/// The pale morning sky behind the sign-in screens' illustrations: white
/// into a soft sky tint, with a few soft circles floating slowly upward —
/// calm, airy and on brand, without competing with the form below.
class MorningSky extends StatefulWidget {
  final Widget? child;
  const MorningSky({super.key, this.child});

  @override
  State<MorningSky> createState() => _MorningSkyState();
}

class _MorningSkyState extends State<MorningSky>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _MorningPainter(_c.value)),
        ),
      ),
      ?widget.child,
    ],
  );
}

class _MorningPainter extends CustomPainter {
  final double t;
  const _MorningPainter(this.t);

  static const _bubbles = [
    // x, start y, radius, speed, phase
    (0.12, 0.9, 26.0, 1.0, 0.0),
    (0.82, 0.7, 40.0, 0.7, 0.35),
    (0.55, 1.0, 16.0, 1.3, 0.6),
    (0.3, 0.6, 12.0, 1.1, 0.15),
    (0.92, 1.05, 20.0, 0.9, 0.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF), Colors.white],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
    // A soft sun of light in the top corner.
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.05),
      size.width * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.9),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.9, size.height * 0.05),
            radius: size.width * 0.55,
          ),
        ),
    );
    for (final (x, y0, r, speed, phase) in _bubbles) {
      final p = (t * speed + phase) % 1;
      final y = size.height * (y0 - p * 0.9);
      final fade = math.sin(p * math.pi); // in at the bottom, out at the top
      final c = Offset(
        size.width * x + 10 * math.sin((t + phase) * 2 * math.pi),
        y,
      );
      canvas.drawCircle(
        c,
        r,
        Paint()..color = const Color(0xFF7DD3FC).withValues(alpha: 0.18 * fade),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.7 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_MorningPainter old) => old.t != t;
}

// ─────────────────────────── Brand ───────────────────────────

/// The Aadya mark on a white rounded tile.
class BrandMark extends StatelessWidget {
  final double size;
  final bool shadow;
  const BrandMark({super.key, this.size = 44, this.shadow = true});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * 0.28),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.18),
                blurRadius: size * 0.4,
                offset: Offset(0, size * 0.12),
              ),
            ]
          : null,
    ),
    padding: EdgeInsets.all(size * 0.01),
    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
  );
}

/// "Aadya Plus" set in the brand: Aadya in ink (or white), Plus in sky.
class Wordmark extends StatelessWidget {
  final double size;
  final bool onDark;
  const Wordmark({super.key, this.size = 20, this.onDark = false});

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'Aadya ',
          style: AppType.sans(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: onDark ? Colors.white : AppColors.textStrong,
            letterSpacing: -0.4,
          ),
        ),
        TextSpan(
          text: 'Plus',
          style: AppType.sans(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: onDark ? const Color(0xFFBAE6FD) : AppColors.brand,
            letterSpacing: -0.4,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────── Fixed sign-in layout ───────────────────────────

/// A sign-in screen as one fixed page: the [hero] at the top and a white
/// sheet holding the form below it, reaching the bottom edge. The form is
/// measured and the hero takes all the space left over (never less than
/// [minHeroHeight]), so the page is filled with no scrolling and no empty
/// band. When the keyboard opens, the sheet glides up over the hero
/// (keeping its [topBar] visible) so the field being typed in stays in
/// view, and only then can the form scroll.
class AuthLayout extends StatefulWidget {
  final double minHeroHeight;
  final Widget hero;
  final Widget child;
  final Widget? topBar;
  const AuthLayout({
    super.key,
    required this.minHeroHeight,
    required this.hero,
    required this.child,
    this.topBar,
  });

  static const overlap = 28.0;

  @override
  State<AuthLayout> createState() => _AuthLayoutState();
}

class _AuthLayoutState extends State<AuthLayout> {
  double? _content;

  void _measured(Size size) {
    if (_content == size.height) return;
    setState(() => _content = size.height);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size.height;
    final typing = media.viewInsets.bottom > 0;
    final bottomPad = typing ? 16.0 : media.padding.bottom;
    final hero = _content == null
        ? widget.minHeroHeight
        : (screen - _content! - bottomPad + AuthLayout.overlap).clamp(
            widget.minHeroHeight,
            screen * 0.56,
          );
    final top = typing
        ? media.padding.top + 60
        : hero - AuthLayout.overlap;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Opacity(
          // One frame to measure the form before anything shows.
          opacity: _content == null ? 0 : 1,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                top: 0,
                left: 0,
                right: 0,
                height: hero,
                child: widget.hero,
              ),
              if (widget.topBar != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(bottom: false, child: widget.topBar!),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                top: top,
                left: 0,
                right: 0,
                bottom: 0,
                child: _Sheet(
                  child: ScrollConfiguration(
                    behavior: const _NoStretch(),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(bottom: bottomPad),
                      child: _SizeReporter(
                        onSize: _measured,
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reports its child's laid-out size after each layout that changes it.
class _SizeReporter extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onSize;
  const _SizeReporter({required this.onSize, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  ValueChanged<Size> onSize;
  Size? _last;
  _RenderSizeReporter(this.onSize);

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    _last = size;
    final reported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
  }
}

class _Sheet extends StatefulWidget {
  final Widget child;
  const _Sheet({required this.child});

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (!_c.isAnimating && !_c.isCompleted) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final v = Curves.easeOutCubic.transform(_c.value);
      return Transform.translate(offset: Offset(0, 44 * (1 - v)), child: child);
    },
    child: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: widget.child,
    ),
  );
}

class _NoStretch extends ScrollBehavior {
  const _NoStretch();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// A hero for the sign-in screens: the morning sky with an illustration
/// floating in it, rising into place. The illustration grows with the
/// space the hero is given, up to [maxIllustrationHeight].
class IllustratedHero extends StatelessWidget {
  final String illustration;
  final double maxIllustrationHeight;
  const IllustratedHero({
    super.key,
    required this.illustration,
    this.maxIllustrationHeight = 220,
  });

  @override
  Widget build(BuildContext context) => MorningSky(
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, AuthLayout.overlap + 16),
        child: LayoutBuilder(
          builder: (context, box) => Center(
            child: AppEntrance(
              child: AppIllustration(
                illustration,
                height: box.maxHeight.clamp(0.0, maxIllustrationHeight),
                float: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A round back button for the sign-in top bars.
class OnboardingBack extends StatelessWidget {
  final VoidCallback onPressed;
  const OnboardingBack({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Back',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.85),
        ),
        icon: const Icon(
          LucideIcons.arrowLeft,
          size: 20,
          color: AppColors.textStrong,
        ),
      ),
    ),
  );
}

/// A note above a form: a calm blue notice or a red error, one short line
/// when there's no title.
class AuthNote extends StatelessWidget {
  final String message;
  final String? title;
  final bool isError;
  final VoidCallback? onClose;
  const AuthNote.error(this.message, {super.key, this.onClose})
    : title = null,
      isError = true;
  const AuthNote.info(this.message, {super.key, this.title, this.onClose})
    : isError = false;

  @override
  Widget build(BuildContext context) {
    final tone = isError ? AppColors.error : AppColors.brand;
    final compact = title == null;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: compact
            ? const EdgeInsets.fromLTRB(10, 8, 6, 8)
            : const EdgeInsets.fromLTRB(12, 12, 6, 12),
        decoration: BoxDecoration(
          color: isError ? AppColors.errorBg : AppColors.brandVeryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tone.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 22 : 30,
              height: compact ? 22 : 30,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? LucideIcons.circleAlert : LucideIcons.info,
                size: compact ? 13 : 15,
                color: tone,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: AppType.sans(
                        fontSize: AppType.body,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                  Text(
                    message,
                    style: AppType.sans(
                      fontSize: AppType.small,
                      fontWeight: compact ? FontWeight.w600 : FontWeight.w400,
                      color: compact ? tone : AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (onClose != null)
              Semantics(
                button: true,
                label: 'Dismiss',
                child: InkResponse(
                  onTap: onClose,
                  radius: 16,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      LucideIcons.x,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
