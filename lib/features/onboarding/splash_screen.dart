import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/app_ui.dart';
import 'onboarding_widgets.dart';

/// The brand moment at launch: the sky opens, the mark pops in with a shine
/// sweeping across it, the name rises letter by letter and a thin line
/// fills while the saved session is read. Calls [onFinished] once the
/// sequence has played (the launch gate also waits for the session).
class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  const SplashScreen({super.key, this.onFinished});

  static const duration = Duration(milliseconds: 2100);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SplashScreen.duration,
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFinished?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onFinished?.call(),
      );
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _span(double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_c.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.brand,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final bloom = _span(0, 0.45);
            final pop = _span(0.08, 0.42, Curves.easeOutBack);
            final shine = _span(0.38, 0.66, Curves.easeInOut);
            final tag = _span(0.62, 0.84);
            final line = _span(0.55, 1, Curves.easeInOutCubic);
            return Stack(
              fit: StackFit.expand,
              children: [
                SkyBackdrop(bloom: bloom),
                _Rings(progress: _span(0.1, 0.75)),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 0.6 + 0.4 * pop,
                        child: Opacity(
                          opacity: pop.clamp(0.0, 1.0),
                          child: _ShiningMark(shine: shine),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _RisingName(progress: _span(0.3, 0.7)),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: tag,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - tag)),
                          child: Text(
                            'Your health, connected',
                            style: AppType.sans(
                              fontSize: AppType.title,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).padding.bottom + 48,
                  child: Center(
                    child: Opacity(
                      opacity: tag,
                      child: _LoadingLine(progress: line),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The mark on its own — no tile — with a band of light sweeping across
/// it, masked to the mark's shape so only the logo catches the light.
class _ShiningMark extends StatelessWidget {
  final double shine;
  const _ShiningMark({required this.shine});

  static const size = 140.0;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset('assets/logo_mark.png', width: size, height: size, fit: BoxFit.contain);
    if (shine <= 0 || shine >= 1) return mark;
    final at = -0.2 + 1.4 * shine;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.7),
          Colors.white.withValues(alpha: 0),
        ],
        stops: [(at - 0.14).clamp(0.0, 1.0), at.clamp(0.0, 1.0), (at + 0.14).clamp(0.0, 1.0)],
      ).createShader(rect),
      child: mark,
    );
  }
}

/// "Aadya Plus", each letter rising and fading in a beat after the last.
class _RisingName extends StatelessWidget {
  final double progress;
  const _RisingName({required this.progress});

  static const _word = 'Aadya Plus';

  @override
  Widget build(BuildContext context) {
    final letters = _word.characters.toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letters.length; i++)
          Builder(
            builder: (_) {
              final start = i / letters.length * 0.55;
              final v = Curves.easeOutCubic.transform(
                ((progress - start) / 0.45).clamp(0.0, 1.0),
              );
              final plus = i >= 6;
              return Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - v)),
                  child: Text(
                    letters[i],
                    style: AppType.sans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: plus ? const Color(0xFFBAE6FD) : Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Two thin rings opening out from the mark, like a pulse.
class _Rings extends StatelessWidget {
  final double progress;
  const _Rings({required this.progress});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _RingsPainter(progress)),
  );
}

class _RingsPainter extends CustomPainter {
  final double p;
  const _RingsPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0 || p >= 1) return;
    final c = Offset(size.width / 2, size.height / 2 - 40);
    for (final lag in const [0.0, 0.25]) {
      final v = ((p - lag) / (1 - lag)).clamp(0.0, 1.0);
      if (v <= 0) continue;
      canvas.drawCircle(
        c,
        60 + v * size.shortestSide * 0.42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.35 * math.pow(1 - v, 1.4)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.p != p;
}

class _LoadingLine extends StatelessWidget {
  final double progress;
  const _LoadingLine({required this.progress});

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 3,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(2),
    ),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: progress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}
