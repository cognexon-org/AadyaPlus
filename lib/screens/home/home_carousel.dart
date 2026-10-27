import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/ui/app_ui.dart';

/// Which animated scene a slide draws.
enum HeroArt { video, lab, delivery }

class HeroSlide {
  final String tag;
  final IconData tagIcon;
  final String title;
  final String body;
  final String cta;
  final HeroArt art;
  final List<Color> gradient;
  final VoidCallback onTap;
  const HeroSlide({
    required this.tag,
    required this.tagIcon,
    required this.title,
    required this.body,
    required this.cta,
    required this.art,
    required this.gradient,
    required this.onTap,
  });
}

/// Home's first impression: three service cards, each with a scene drawn
/// and animated in code. The neighbours peek in and scale as you swipe,
/// the carousel moves on by itself (pausing while touched), and story-style
/// bars show how long until the next card.
class HeroCarousel extends StatefulWidget {
  final List<HeroSlide> slides;
  const HeroCarousel({super.key, required this.slides});

  static const height = 208.0;
  static const interval = Duration(seconds: 5);

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> with SingleTickerProviderStateMixin {
  final _pages = PageController(viewportFraction: 0.9);
  late final _timer = AnimationController(vsync: this, duration: HeroCarousel.interval)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
  double _page = 0;
  int _index = 0;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() => setState(() => _page = _pages.page ?? 0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.of(context).disableAnimations;
    if (_still) {
      _timer.stop();
    } else if (!_timer.isAnimating) {
      _timer.forward(from: 0);
    }
  }

  void _next() {
    if (!_pages.hasClients || !mounted) return;
    _pages.animateToPage(
      (_index + 1) % widget.slides.length,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  void _pause() => _timer.stop();
  void _resume() {
    if (!_still) _timer.forward();
  }

  @override
  void dispose() {
    _timer.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: HeroCarousel.height,
          child: Listener(
            onPointerDown: (_) => _pause(),
            onPointerUp: (_) => _resume(),
            onPointerCancel: (_) => _resume(),
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.slides.length,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _index = i);
                if (!_still) _timer.forward(from: 0);
              },
              itemBuilder: (_, i) {
                final d = (_page - i).clamp(-1.0, 1.0);
                return Transform.scale(
                  scale: 1 - 0.06 * d.abs(),
                  child: Opacity(
                    opacity: 1 - 0.35 * d.abs(),
                    child: _Card(slide: widget.slides[i], offset: d, active: i == _index),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Story bars: the current one fills until the next card.
        AnimatedBuilder(
          animation: _timer,
          builder: (_, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.slides.length; i++)
                AnimatedContainer(
                  duration: AppMotion.medium,
                  curve: AppMotion.enter,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 28 : 8,
                  height: 6,
                  decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(3)),
                  alignment: Alignment.centerLeft,
                  child: i == _index
                      ? FractionallySizedBox(
                          widthFactor: _still ? 1 : _timer.value.clamp(0.08, 1.0),
                          child: Container(
                            decoration: BoxDecoration(color: widget.slides[i].gradient.last, borderRadius: BorderRadius.circular(3)),
                          ),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final HeroSlide slide;
  final double offset;
  final bool active;
  const _Card({required this.slide, required this.offset, required this.active});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: AppPressable(
        onTap: slide.onTap,
        scale: 0.98,
        semanticLabel: '${slide.title}. ${slide.cta}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: slide.gradient),
            ),
            child: Stack(
              children: [
                // Soft shapes inside the card — depth without any glow outside it.
                Positioned(right: -40 + offset * 30, top: -50, child: _Blob(size: 170, alpha: 0.12)),
                Positioned(left: -30 - offset * 20, bottom: -60, child: _Blob(size: 140, alpha: 0.08)),
                Positioned.fill(child: CustomPaint(painter: _GrainPainter())),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(slide.tagIcon, size: 12, color: Colors.white),
                                  const SizedBox(width: 5),
                                  Text(slide.tag, style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: Colors.white)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Transform.translate(
                              offset: Offset(-offset * w * 0.06, 0),
                              child: Text(
                                slide.title,
                                maxLines: 2,
                                style: AppType.sans(fontSize: 21, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              slide.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.sans(fontSize: AppType.small, height: 1.35, color: Colors.white.withValues(alpha: 0.88)),
                            ),
                            const Spacer(),
                            Container(
                              height: 34,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(slide.cta, style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w800, color: slide.gradient.last)),
                                  const SizedBox(width: 6),
                                  Icon(LucideIcons.arrowRight, size: 15, color: slide.gradient.last),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(offset * w * 0.12, 0),
                        child: SizedBox(width: 124, height: double.infinity, child: _Scene(art: slide.art, active: active, tint: slide.gradient.last)),
                      ),
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

class _Blob extends StatelessWidget {
  final double size;
  final double alpha;
  const _Blob({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
  );
}

/// A faint diagonal sheen, so the gradient reads as a surface, not a fill.
class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.5), p);
  }

  @override
  bool shouldRepaint(_GrainPainter old) => false;
}

/// Loops the scene while its card is the one on screen.
class _Scene extends StatefulWidget {
  final HeroArt art;
  final bool active;
  final Color tint;
  const _Scene({required this.art, required this.active, required this.tint});

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  void _sync() {
    if (widget.active && !MediaQuery.of(context).disableAnimations) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Scene old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => HeroArtFrame(art: widget.art, t: _c.value, tint: widget.tint),
    ),
  );
}

/// One frame of a scene at time [t] (0–1). Public for previews.
class HeroArtFrame extends StatelessWidget {
  final HeroArt art;
  final double t;
  final Color tint;
  const HeroArtFrame({super.key, required this.art, required this.t, required this.tint});

  @override
  // Drawn at one design size and scaled to whatever room the card gives.
  Widget build(BuildContext context) => FittedBox(
    child: SizedBox(
      width: 124,
      height: 168,
      child: switch (art) {
        HeroArt.video => _VideoScene(t: t, tint: tint),
        HeroArt.lab => _LabScene(t: t, tint: tint),
        HeroArt.delivery => _DeliveryScene(t: t, tint: tint),
      },
    ),
  );
}

double _wave(double t, [double phase = 0]) => math.sin((t + phase) * 2 * math.pi);

// ─────────────────────────── Video consult ───────────────────────────

class _VideoScene extends StatelessWidget {
  final double t;
  final Color tint;
  const _VideoScene({required this.t, required this.tint});

  @override
  Widget build(BuildContext context) {
    final blink = (t * 2) % 1 < 0.6;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // The phone, gently floating.
        Transform.translate(
          offset: Offset(6, 4 * _wave(t)),
          child: Transform.rotate(
            angle: -0.07,
            child: Container(
              width: 82,
              height: 150,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 8))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  color: Color.alphaBlend(tint.withValues(alpha: 0.10), Colors.white),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: blink ? 1 : 0.25,
                              child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                            ),
                            const SizedBox(width: 3),
                            Text('LIVE', style: AppType.sans(fontSize: 7, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // The doctor: a calm figure with a stethoscope.
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CustomPaint(painter: _PersonPainter(tint: tint, nod: _wave(t) * 1.5)),
                      ),
                      const Spacer(),
                      SizedBox(height: 22, width: 64, child: CustomPaint(painter: _EcgPainter(t: t, color: tint))),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CallDot(icon: LucideIcons.micOff, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          _CallDot(icon: LucideIcons.phoneOff, color: const Color(0xFFEF4444), filled: true),
                          const SizedBox(width: 6),
                          _CallDot(icon: LucideIcons.video, color: AppColors.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // A typing bubble and a heart, drifting beside the phone.
        Positioned(
          left: 0,
          top: 26 + 3 * _wave(t, 0.3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10), bottomRight: Radius.circular(10), bottomLeft: Radius.circular(3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 4,
                    height: 4,
                    transform: Matrix4.translationValues(0, -2.5 * math.max(0, _wave(t * 2, i * 0.15)), 0),
                    decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 30 + 5 * _wave(t, 0.6),
          child: Transform.scale(
            scale: 1 + 0.15 * math.max(0, _wave(t * 2)),
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(LucideIcons.heart, size: 14, color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }
}

class _CallDot extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool filled;
  const _CallDot({required this.icon, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(color: filled ? color : Colors.white, shape: BoxShape.circle),
    child: Icon(icon, size: 8.5, color: filled ? Colors.white : color),
  );
}

class _PersonPainter extends CustomPainter {
  final Color tint;
  final double nod;
  const _PersonPainter({required this.tint, required this.nod});

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    // Coat.
    canvas.drawPath(
      Path()
        ..moveTo(cx - 22, s.height)
        ..quadraticBezierTo(cx - 22, s.height * 0.62, cx, s.height * 0.6)
        ..quadraticBezierTo(cx + 22, s.height * 0.62, cx + 22, s.height)
        ..close(),
      Paint()..color = Colors.white,
    );
    // Collar in the accent.
    canvas.drawPath(
      Path()
        ..moveTo(cx - 6, s.height * 0.6)
        ..lineTo(cx, s.height * 0.78)
        ..lineTo(cx + 6, s.height * 0.6),
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    // Stethoscope.
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, s.height * 0.72), width: 22, height: 18),
      0.2,
      2.7,
      false,
      Paint()
        ..color = AppColors.textStrong.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Head, nodding a little.
    canvas.drawCircle(Offset(cx, s.height * 0.34 + nod), 11, Paint()..color = const Color(0xFFF2C6A7));
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, s.height * 0.32 + nod), radius: 11.5),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF3B2A20),
    );
  }

  @override
  bool shouldRepaint(_PersonPainter old) => old.nod != nod;
}

/// A heartbeat trace drawn left to right, then fading for the next beat.
class _EcgPainter extends CustomPainter {
  final double t;
  final Color color;
  const _EcgPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final mid = s.height / 2;
    final path = Path()..moveTo(0, mid);
    final w = s.width;
    for (final (x, y) in [
      (0.22, 0.0), (0.3, -0.25), (0.36, 0.0), (0.42, 0.0), (0.47, 0.45), (0.53, -0.9), (0.58, 0.35), (0.63, 0.0), (0.75, 0.0), (0.82, -0.2), (0.88, 0.0), (1.0, 0.0),
    ]) {
      path.lineTo(w * x, mid + y * mid);
    }
    final metric = path.computeMetrics().first;
    final draw = (t * 1.3).clamp(0.0, 1.0);
    final fade = t > 0.85 ? (1 - (t - 0.85) / 0.15) : 1.0;
    canvas.drawPath(
      metric.extractPath(0, metric.length * draw),
      Paint()
        ..color = color.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final tip = metric.getTangentForOffset(metric.length * draw)?.position;
    if (tip != null && draw < 1) canvas.drawCircle(tip, 2.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_EcgPainter old) => old.t != t;
}

// ─────────────────────────── Lab at home ───────────────────────────

class _LabScene extends StatelessWidget {
  final double t;
  final Color tint;
  const _LabScene({required this.t, required this.tint});

  @override
  Widget build(BuildContext context) {
    // A drop falls in the first third; the tube fills, holds, and drains.
    final fill = t < 0.3 ? 0.2 : t < 0.65 ? 0.2 + 0.55 * Curves.easeOutCubic.transform((t - 0.3) / 0.35) : t < 0.85 ? 0.75 : 0.75 - 0.55 * ((t - 0.85) / 0.15);
    final dropY = t < 0.3 ? Curves.easeIn.transform(t / 0.3) : -1.0;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // A small house badge: collected at home.
        Positioned(
          left: 0,
          bottom: 22 + 4 * _wave(t, 0.2),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Icon(LucideIcons.house, size: 18, color: tint),
          ),
        ),
        Transform.translate(
          offset: Offset(-2, 3 * _wave(t)),
          child: SizedBox(
            width: 50,
            height: 150,
            child: CustomPaint(painter: _TubePainter(fill: fill, t: t, liquid: Colors.white, glass: Colors.white, dropY: dropY)),
          ),
        ),
        Positioned(
          right: 0,
          top: 70 + 4 * _wave(t, 0.55),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.fileCheck, size: 10, color: tint),
                const SizedBox(width: 3),
                Text('Report', style: AppType.sans(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TubePainter extends CustomPainter {
  final double fill;
  final double t;
  final Color liquid;
  final Color glass;
  final double dropY;
  const _TubePainter({required this.fill, required this.t, required this.liquid, required this.glass, required this.dropY});

  @override
  void paint(Canvas canvas, Size s) {
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(s.width * 0.2, s.height * 0.22, s.width * 0.6, s.height * 0.72),
      bottomLeft: Radius.circular(s.width * 0.3),
      bottomRight: Radius.circular(s.width * 0.3),
    );
    // Glass.
    canvas.drawRRect(body, Paint()..color = glass.withValues(alpha: 0.22));
    // Liquid, with a moving meniscus.
    canvas.save();
    canvas.clipRRect(body);
    final top = body.bottom - body.height * fill;
    final wave = Path()..moveTo(body.left, top);
    for (var x = 0.0; x <= body.width; x += 2) {
      wave.lineTo(body.left + x, top + 2 * math.sin((x / body.width + t) * 2 * math.pi));
    }
    wave
      ..lineTo(body.right, body.bottom)
      ..lineTo(body.left, body.bottom)
      ..close();
    canvas.drawPath(wave, Paint()..color = liquid.withValues(alpha: 0.92));
    // Bubbles rising.
    for (var i = 0; i < 4; i++) {
      final p = (t * 1.6 + i * 0.27) % 1;
      final y = body.bottom - p * body.height * fill;
      if (y < top + 4) continue;
      canvas.drawCircle(Offset(body.left + body.width * (0.3 + 0.15 * i), y), 1.6 + i * 0.4, Paint()..color = const Color(0x33000000));
    }
    canvas.restore();
    canvas.drawRRect(body, Paint()
      ..color = glass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // Cap.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.12, s.height * 0.14, s.width * 0.76, s.height * 0.1), const Radius.circular(4)),
      Paint()..color = glass,
    );
    // Shine down the glass.
    canvas.drawLine(
      Offset(body.left + body.width * 0.22, body.top + 10),
      Offset(body.left + body.width * 0.22, body.bottom - body.width * 0.4),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    // The falling drop.
    if (dropY >= 0) {
      final y = s.height * (0.0 + 0.3 * dropY);
      canvas.drawPath(
        Path()
          ..moveTo(s.width / 2, y - 7)
          ..quadraticBezierTo(s.width / 2 + 5, y + 1, s.width / 2, y + 4)
          ..quadraticBezierTo(s.width / 2 - 5, y + 1, s.width / 2, y - 7),
        Paint()..color = liquid,
      );
    }
  }

  @override
  bool shouldRepaint(_TubePainter old) => old.t != t;
}

// ─────────────────────────── Medicines delivered ───────────────────────────

class _DeliveryScene extends StatelessWidget {
  final double t;
  final Color tint;
  const _DeliveryScene({required this.t, required this.tint});

  @override
  Widget build(BuildContext context) {
    final travel = Curves.easeInOutCubic.transform((t / 0.75).clamp(0.0, 1.0));
    final arrived = t >= 0.75;
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final route = _route(size);
        final metric = route.computeMetrics().first;
        final pos = metric.getTangentForOffset(metric.length * travel)!.position;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _RoutePainter(metric: metric, progress: travel))),
            // Destination pin, pulsing once the parcel arrives.
            Positioned(
              left: size.width * 0.84 - 15,
              top: size.height * 0.16 - 32,
              child: Transform.scale(
                scale: arrived ? 1 + 0.12 * math.sin(((t - 0.75) / 0.25) * math.pi) : 1,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 3))]),
                  child: Icon(arrived ? LucideIcons.check : LucideIcons.mapPin, size: 16, color: tint),
                ),
              ),
            ),
            // Pharmacy at the start.
            Positioned(
              left: size.width * 0.08 - 14,
              top: size.height * 0.86 - 14,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(9)),
                child: Icon(LucideIcons.store, size: 14, color: tint),
              ),
            ),
            // The parcel, bobbing along the route.
            Positioned(
              left: pos.dx - 22,
              top: pos.dy - 26 - 3 * _wave(t * 3).abs(),
              child: Opacity(
                opacity: arrived ? (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0) : 1,
                child: Container(
                  width: 44,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Icon(LucideIcons.package, size: 21, color: tint),
                ),
              ),
            ),
            // A pill or two hopping out on arrival.
            if (arrived)
              for (var i = 0; i < 3; i++)
                Builder(
                  builder: (_) {
                    final p = ((t - 0.75) / 0.25).clamp(0.0, 1.0);
                    final angle = -math.pi / 2 + (i - 1) * 0.7;
                    return Positioned(
                      left: size.width * 0.84 - 4 + math.cos(angle) * 26 * p,
                      top: size.height * 0.16 - 18 + math.sin(angle) * 26 * p,
                      child: Opacity(
                        opacity: 1 - p,
                        child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ),
                    );
                  },
                ),
          ],
        );
      },
    );
  }

  static Path _route(Size s) => Path()
    ..moveTo(s.width * 0.08, s.height * 0.86)
    ..cubicTo(s.width * 0.55, s.height * 0.95, s.width * 0.05, s.height * 0.35, s.width * 0.5, s.height * 0.42)
    ..quadraticBezierTo(s.width * 0.85, s.height * 0.46, s.width * 0.84, s.height * 0.16);
}

class _RoutePainter extends CustomPainter {
  final PathMetric metric;
  final double progress;
  const _RoutePainter({required this.metric, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var d = 0.0; d < metric.length; d += 9) {
      canvas.drawPath(metric.extractPath(d, math.min(d + 4, metric.length)), dash);
    }
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.progress != progress;
}
