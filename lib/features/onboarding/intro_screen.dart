import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ui/app_ui.dart';
import 'onboarding_widgets.dart';

/// The first-launch walkthrough: one slide per service, each in its own
/// accent. The illustration drifts at a different speed to the text as you
/// swipe, and the colour flows from one service to the next.
class IntroScreen extends StatefulWidget {
  final VoidCallback onDone;
  const IntroScreen({super.key, required this.onDone});

  static const _seenKey = 'intro_seen_v1';

  static Future<bool> hasBeenSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_seenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {}
  }

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _Slide {
  final String illustration;
  final String tag;
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  const _Slide(
    this.illustration,
    this.tag,
    this.icon,
    this.title,
    this.body,
    this.accent,
  );
}

final _slides = [
  _Slide(
    Illustrations.onboardDoctors,
    'Doctors',
    LucideIcons.stethoscope,
    'See a doctor, your way',
    'Book a clinic visit or a video consultation with verified doctors, and keep every prescription in one place.',
    ModuleAccent.doctor.color,
  ),
  _Slide(
    Illustrations.onboardLab,
    'Lab tests',
    LucideIcons.testTubeDiagonal,
    'Lab tests at your doorstep',
    'A phlebotomist collects your sample at home. Reports land in the app the moment they’re ready.',
    ModuleAccent.lab.color,
  ),
  _Slide(
    Illustrations.onboardDelivery,
    'Pharmacy',
    LucideIcons.pill,
    'Medicines, delivered',
    'Order from pharmacies near you, upload a prescription and follow your order to the door.',
    ModuleAccent.pharmacy.color,
  ),
  _Slide(
    Illustrations.onboardPhysio,
    'Physiotherapy',
    LucideIcons.activity,
    'Recover with a physio',
    'Sessions at home or at the clinic, with a care plan that tracks your progress week by week.',
    ModuleAccent.physio.color,
  ),
];

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() => setState(() => _page = _pages.page ?? 0));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Color get _accent {
    final i = _page.floor().clamp(0, _slides.length - 1);
    final j = (i + 1).clamp(0, _slides.length - 1);
    return Color.lerp(_slides[i].accent, _slides[j].accent, _page - i)!;
  }

  bool get _last => _page.round() == _slides.length - 1;

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    await IntroScreen.markSeen();
    widget.onDone();
  }

  void _next() {
    if (_last) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final tint = Color.alphaBlend(
      accent.withValues(alpha: 0.07),
      Colors.white,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // The upper half takes on the current service's colour.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [tint, Colors.white],
                    stops: const [0.35, 0.75],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                    child: Row(
                      children: [
                        Image.asset('assets/logo_mark.png', height: 40),
                        const SizedBox(width: 10),
                        const Wordmark(size: 19),
                        const Spacer(),
                        AnimatedOpacity(
                          opacity: _last ? 0 : 1,
                          duration: AppMotion.fast,
                          child: TextButton(
                            onPressed: _last ? null : _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: const Text('Skip'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _slides.length,
                      itemBuilder: (_, i) =>
                          _SlideView(slide: _slides[i], offset: _page - i),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Row(
                      children: [
                        _Dots(page: _page, count: _slides.length, color: accent),
                        const Spacer(),
                        _NextButton(
                          last: _last,
                          color: accent,
                          onPressed: _next,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;

  /// How far this slide is from centre: 0 on screen, ±1 one page away.
  final double offset;
  const _SlideView({required this.slide, required this.offset});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final d = offset.clamp(-1.0, 1.0);
    final fade = (1 - d.abs()).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, box) {
        final art = (box.maxHeight * 0.58).clamp(160.0, 340.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // The illustration lags behind the swipe, the text leads it.
              Transform.translate(
                offset: Offset(d * width * 0.35, 0),
                child: Opacity(
                  opacity: fade,
                  child: SizedBox(
                    height: art,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _Halo(color: slide.accent, size: art * 0.95),
                        AppIllustration(
                          slide.illustration,
                          height: art * 0.86,
                          float: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Transform.translate(
                offset: Offset(-d * width * 0.15, 0),
                child: Opacity(
                  opacity: fade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Tag(icon: slide.icon, text: slide.tag, color: slide.accent),
                      const SizedBox(height: 14),
                      Text(
                        slide.title,
                        style: AppType.sans(
                          fontSize: 27,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: AppColors.textStrong,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        slide.body,
                        style: AppType.sans(
                          fontSize: 14.5,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

/// A soft disc of the service's colour behind its illustration, with a
/// thin orbit ring.
class _Halo extends StatelessWidget {
  final Color color;
  final double size;
  const _Halo({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.14),
              color.withValues(alpha: 0.04),
            ],
          ),
        ),
      ),
      Container(
        width: size * 0.72,
        height: size * 0.72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
      ),
    ],
  );
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Tag({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppType.sans(
            fontSize: AppType.small,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Page dots; the current one stretches into a pill as you swipe onto it.
class _Dots extends StatelessWidget {
  final double page;
  final int count;
  final Color color;
  const _Dots({required this.page, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < count; i++)
        Builder(
          builder: (_) {
            final near = (1 - (page - i).abs()).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.only(right: 6),
              width: 8 + 18 * near,
              height: 8,
              decoration: BoxDecoration(
                color: Color.lerp(AppColors.borderStrong, color, near),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          },
        ),
    ],
  );
}

/// A round arrow button that widens into "Get started" on the last slide.
class _NextButton extends StatelessWidget {
  final bool last;
  final Color color;
  final VoidCallback onPressed;
  const _NextButton({
    required this.last,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onPressed,
    semanticLabel: last ? 'Get started' : 'Next',
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      height: 56,
      width: last ? 170 : 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRect(
        child: OverflowBox(
          maxWidth: 170,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                child: last
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          'Get started',
                          style: AppType.sans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const Icon(LucideIcons.arrowRight, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    ),
  );
}
