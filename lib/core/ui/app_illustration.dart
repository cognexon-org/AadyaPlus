import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The unDraw illustrations bundled in assets/illustrations (recoloured to
/// the Aadya sky), by name.
abstract final class Illustrations {
  static const onboardDoctors = 'onboard_doctors';
  static const onboardVideo = 'onboard_video';
  static const onboardLab = 'onboard_lab';
  static const onboardDelivery = 'onboard_delivery';
  static const onboardPhysio = 'onboard_physio';
  static const medicalCare = 'medical_care';
  static const login = 'login';
  static const otp = 'otp';
  static const register = 'register';
  static const profileSetup = 'profile_setup';
  static const forgotPassword = 'forgot_password';
  static const booked = 'booked';
  static const success = 'success';
  static const emptyCalendar = 'empty_calendar';
  static const emptyCart = 'empty_cart';
  static const emptyNotifications = 'empty_notifications';
  static const emptyData = 'empty_data';
  static const notFound = 'not_found';
  static const offline = 'offline';
  static const labReport = 'lab_report';
  static const prescription = 'prescription';
  static const pharmacy = 'pharmacy';
  static const payments = 'payments';
  static const address = 'address';
  static const location = 'location';
  static const onTheWay = 'on_the_way';
  static const exercise = 'exercise';
  static const family = 'family';
}

/// An illustration that, when [float] is on, drifts gently up and down —
/// alive, never busy. Holds still under reduced motion.
class AppIllustration extends StatefulWidget {
  final String name;
  final double? height;
  final double? width;
  final bool float;
  const AppIllustration(
    this.name, {
    super.key,
    this.height,
    this.width,
    this.float = false,
  });

  @override
  State<AppIllustration> createState() => _AppIllustrationState();
}

class _AppIllustrationState extends State<AppIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.of(context).disableAnimations;
    if (widget.float && !still) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picture = SvgPicture.asset(
      'assets/illustrations/${widget.name}.svg',
      height: widget.height,
      width: widget.width,
      fit: BoxFit.contain,
    );
    if (!widget.float) return picture;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 6 * math.sin(_c.value * 2 * math.pi)),
        child: child,
      ),
      child: picture,
    );
  }
}
