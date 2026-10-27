import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/app_ui.dart';
import '../../models/doctor.dart';
import '../../providers/doctor_provider.dart';
import '../../services/professional_service.dart';
import '../appointments/book_appointment_screen.dart';

/// A doctor's or physio's profile: credentials, the ways they can be seen
/// and what each costs, what they treat, where, and what patients said.
class DoctorDetailScreen extends StatefulWidget {
  final String doctorId;
  const DoctorDetailScreen({super.key, required this.doctorId});

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  ProfessionalProfile? _profile;
  bool _aboutOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final doctor = context.read<DoctorProvider>().findById(widget.doctorId);
    if (doctor == null) return;
    try {
      final p = await ProfessionalService.instance.profile(doctor.id, doctor.professionalType);
      if (mounted) setState(() => _profile = p);
    } catch (_) {
      // The directory entry already has everything needed to book.
    }
  }

  void _book(Doctor doctor, [String? visit]) => Navigator.of(context).push(
    AppPageRoute(builder: (_) => BookAppointmentScreen(doctor: doctor, initialVisit: visit)),
  );

  Future<void> _directions(Doctor d) async {
    final query = Uri.encodeComponent(
      [d.clinicName, d.clinicAddress].where((e) => e.isNotEmpty).join(', '),
    );
    final uri = d.latitude != null
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=${d.latitude},${d.longitude}')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<DoctorProvider>();
    final doctor = directory.findById(widget.doctorId);
    if (doctor == null) {
      return Scaffold(
        appBar: const AppTopBar(title: 'Profile'),
        body: Center(
          child: directory.isLoading
              ? const AppLoading()
              : const AppEmptyState(
                  illustration: Illustrations.notFound,
                  title: 'This profile isn’t available',
                  message: 'They may have stopped taking bookings on Aadya Plus.',
                ),
        ),
      );
    }
    final accent = doctor.isPhysio ? ModuleAccent.physio : ModuleAccent.doctor;
    final p = _profile;
    return ModuleTheme(
      accent: accent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(title: doctor.isPhysio ? 'Physiotherapist' : 'Doctor'),
        body: ListView(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            AppEntrance(child: _Identity(doctor: doctor, accent: accent)),
            const SizedBox(height: 18),
            AppEntrance(index: 1, child: _Stats(doctor: doctor, accent: accent)),
            if (p?.nextAvailable != null) ...[
              const SizedBox(height: 12),
              AppEntrance(index: 2, child: _NextAvailable(slot: p!.nextAvailable!, accent: accent)),
            ],
            const SizedBox(height: 22),
            _Title('Ways to consult'),
            AppEntrance(
              index: 2,
              child: Column(
                children: [
                  if (doctor.clinicEnabled)
                    _VisitOption(
                      icon: LucideIcons.building2,
                      title: 'Clinic visit',
                      caption: doctor.clinicName.isNotEmpty ? doctor.clinicName : 'At the clinic',
                      fee: doctor.consultationFee,
                      accent: accent,
                      onTap: () => _book(doctor, 'clinic'),
                    ),
                  if (doctor.videoEnabled)
                    _VisitOption(
                      icon: LucideIcons.video,
                      title: 'Video call',
                      caption: 'From wherever you are',
                      fee: doctor.videoCallFee,
                      accent: accent,
                      onTap: () => _book(doctor, 'video'),
                    ),
                  if (doctor.homeEnabled)
                    _VisitOption(
                      icon: LucideIcons.house,
                      title: 'Home visit',
                      caption: p != null && p.servesAreas.isNotEmpty
                          ? 'Serves ${p.servesAreas.take(3).join(', ')}'
                          : 'They come to you',
                      fee: doctor.homeVisitFee,
                      accent: accent,
                      onTap: () => _book(doctor, 'home'),
                    ),
                ],
              ),
            ),
            if ((p?.about ?? doctor.description).isNotEmpty) ...[
              const SizedBox(height: 14),
              _Title('About'),
              GestureDetector(
                onTap: () => setState(() => _aboutOpen = !_aboutOpen),
                child: AnimatedSize(
                  duration: AppMotion.medium,
                  alignment: Alignment.topCenter,
                  child: Text(
                    p?.about.isNotEmpty == true ? p!.about : doctor.description,
                    maxLines: _aboutOpen ? null : 4,
                    overflow: _aboutOpen ? null : TextOverflow.ellipsis,
                    style: AppType.sans(
                      fontSize: AppType.body + 0.5,
                      height: 1.55,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
            if ((p?.services ?? const []).isNotEmpty) ...[
              const SizedBox(height: 22),
              _Title(doctor.isPhysio ? 'Treats' : 'Services'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final s in p!.services) _Tag(s, accent)],
              ),
            ],
            if (doctor.languages.isNotEmpty) ...[
              const SizedBox(height: 22),
              _Title('Speaks'),
              Text(
                doctor.languages.join(', '),
                style: AppType.sans(fontSize: AppType.body + 0.5, color: AppColors.textPrimary),
              ),
            ],
            if (doctor.clinicEnabled && (doctor.clinicAddress.isNotEmpty || doctor.clinicName.isNotEmpty)) ...[
              const SizedBox(height: 22),
              _Title('Clinic'),
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.veryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(LucideIcons.mapPin, size: 19, color: accent.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (doctor.clinicName.isNotEmpty)
                            Text(
                              doctor.clinicName,
                              style: AppType.sans(
                                fontSize: AppType.body + 0.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textStrong,
                              ),
                            ),
                          if (doctor.clinicAddress.isNotEmpty)
                            Text(
                              doctor.clinicAddress,
                              style: AppType.sans(
                                fontSize: AppType.small,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _directions(doctor),
                      icon: const Icon(LucideIcons.navigation, size: 15),
                      label: const Text('Directions'),
                      style: TextButton.styleFrom(foregroundColor: accent.color),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            _Reviews(doctor: doctor, profile: p, accent: accent),
          ],
        ),
        bottomNavigationBar: _BookBar(doctor: doctor, accent: accent, onBook: () => _book(doctor)),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  final Doctor doctor;
  final ModuleAccent accent;
  const _Identity({required this.doctor, required this.accent});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      AppAvatar(name: doctor.name, imageUrl: doctor.imageUrl, size: 84, radius: 24, color: accent.color),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doctor.name,
              style: AppType.sans(
                fontSize: 21,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.textStrong,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              doctor.specialties.isNotEmpty ? doctor.specialties.join(' · ') : doctor.specialty,
              style: AppType.sans(
                fontSize: AppType.body,
                fontWeight: FontWeight.w600,
                color: accent.color,
              ),
            ),
            if (doctor.qualifications.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                doctor.qualifications.join(', '),
                style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary),
              ),
            ],
            if (doctor.isVerified) ...[
              const SizedBox(height: 8),
              const AppStatusPill(
                text: 'Verified by Aadya Plus',
                icon: LucideIcons.badgeCheck,
                color: AppColors.brand,
                background: AppColors.brandVeryLight,
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _Stats extends StatelessWidget {
  final Doctor doctor;
  final ModuleAccent accent;
  const _Stats({required this.doctor, required this.accent});

  @override
  Widget build(BuildContext context) {
    final items = [
      (LucideIcons.briefcaseMedical, doctor.experience > 0 ? '${doctor.experience} yrs' : 'New', 'Experience'),
      (LucideIcons.star, doctor.reviews > 0 ? doctor.rating.toStringAsFixed(1) : '–', '${doctor.reviews} reviews'),
      doctor.totalConsultations > 0
          ? (
              LucideIcons.users,
              doctor.totalConsultations >= 1000
                  ? '${(doctor.totalConsultations / 1000).toStringAsFixed(1)}k'
                  : '${doctor.totalConsultations}',
              'Consultations',
            )
          : (LucideIcons.wallet, doctor.fromFee > 0 ? appRupees(doctor.fromFee) : 'Free', 'Starting fee'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: accent.veryLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final (i, (icon, value, label)) in items.indexed) ...[
            if (i > 0) Container(width: 1, height: 36, color: accent.light),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: accent.color),
                      const SizedBox(width: 5),
                      Text(
                        value,
                        style: AppType.sans(
                          fontSize: AppType.title + 1,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextAvailable extends StatelessWidget {
  final Map<String, dynamic> slot;
  final ModuleAccent accent;
  const _NextAvailable({required this.slot, required this.accent});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse('${slot['date']}');
    final time = (slot['startTime'] ?? '').toString();
    if (date == null || time.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = date == today
        ? 'Today'
        : date == today.add(const Duration(days: 1))
        ? 'Tomorrow'
        : DateFormat('EEE, d MMM').format(date);
    final parts = time.split(':');
    final t = DateTime(2000, 1, 1, int.tryParse(parts[0]) ?? 0, int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    return Row(
      children: [
        const AppPulse(color: AppColors.health),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'Next available  '),
              TextSpan(
                text: '$day, ${DateFormat('h:mm a').format(t)}',
                style: AppType.sans(
                  fontSize: AppType.small,
                  fontWeight: FontWeight.w700,
                  color: AppColors.health,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: AppType.sans(
        fontSize: AppType.title + 1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.textStrong,
      ),
    ),
  );
}

class _VisitOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  final double fee;
  final ModuleAccent accent;
  final VoidCallback onTap;
  const _VisitOption({
    required this.icon,
    required this.title,
    required this.caption,
    required this.fee,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppPressable(
      onTap: onTap,
      scale: 0.985,
      semanticLabel: '$title, ${appRupees(fee)}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.veryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: accent.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppType.sans(
                      fontSize: AppType.body + 0.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textStrong,
                    ),
                  ),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              fee > 0 ? appRupees(fee) : 'Free',
              style: AppType.sans(
                fontSize: AppType.title,
                fontWeight: FontWeight.w800,
                color: AppColors.textStrong,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  final ModuleAccent accent;
  const _Tag(this.text, this.accent);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: AppType.sans(
        fontSize: AppType.small,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
  );
}

class _Reviews extends StatelessWidget {
  final Doctor doctor;
  final ProfessionalProfile? profile;
  final ModuleAccent accent;
  const _Reviews({required this.doctor, required this.profile, required this.accent});

  @override
  Widget build(BuildContext context) {
    final reviews = profile?.reviews ?? const [];
    final dist = profile?.ratingDistribution ?? const {};
    final total = dist.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Patient reviews'),
        if (doctor.reviews == 0 && reviews.isEmpty)
          Text(
            'No reviews yet. Patients can review after a completed visit.',
            style: AppType.sans(fontSize: AppType.body, color: AppColors.textSecondary),
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    doctor.rating.toStringAsFixed(1),
                    style: AppType.sans(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textStrong,
                    ),
                  ),
                  _Stars(doctor.rating),
                  const SizedBox(height: 2),
                  Text(
                    '${doctor.reviews} reviews',
                    style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              if (total > 0)
                Expanded(
                  child: Column(
                    children: [
                      for (var star = 5; star >= 1; star--)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 12,
                                child: Text(
                                  '$star',
                                  style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: (dist[star] ?? 0) / total,
                                    minHeight: 6,
                                    backgroundColor: AppColors.panel,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          for (final r in reviews.take(5)) _ReviewTile(review: r),
        ],
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  const _Stars(this.rating);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          LucideIcons.star,
          size: 12,
          color: i <= rating.round() ? const Color(0xFFF59E0B) : AppColors.borderStrong,
        ),
    ],
  );
}

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final patient = review['patientId'];
    final name = patient is Map && (patient['name'] ?? '').toString().isNotEmpty
        ? patient['name'].toString()
        : 'Aadya Plus patient';
    final rating = ((review['overallRating'] ?? 0) as num).toDouble();
    final comment = (review['comments'] ?? '').toString().trim();
    final date = DateTime.tryParse('${review['createdAt']}')?.toLocal();
    final reply = review['professionalResponse'] is Map
        ? (review['professionalResponse']['response'] ?? '').toString().trim()
        : (review['professionalResponse'] ?? '').toString().trim();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: name, size: 30, color: AppColors.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: AppType.sans(
                    fontSize: AppType.body,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
              if (date != null)
                Text(
                  DateFormat('d MMM y').format(date),
                  style: AppType.sans(fontSize: AppType.caption, color: AppColors.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _Stars(rating),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              comment,
              style: AppType.sans(fontSize: AppType.body, height: 1.45, color: AppColors.textPrimary),
            ),
          ],
          if (review['wouldRecommend'] == true) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.thumbsUp, size: 13, color: AppColors.health),
                const SizedBox(width: 5),
                Text(
                  'Recommends',
                  style: AppType.sans(
                    fontSize: AppType.caption,
                    fontWeight: FontWeight.w600,
                    color: AppColors.health,
                  ),
                ),
              ],
            ),
          ],
          if (reply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Reply: $reply',
                style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookBar extends StatelessWidget {
  final Doctor doctor;
  final ModuleAccent accent;
  final VoidCallback onBook;
  const _BookBar({required this.doctor, required this.accent, required this.onBook});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consultation from',
                  style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                ),
                Text(
                  doctor.fromFee > 0 ? appRupees(doctor.fromFee) : 'Free',
                  style: AppType.sans(
                    fontSize: AppType.figure,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textStrong,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppButton(label: 'Book appointment', icon: LucideIcons.calendarPlus, onPressed: onBook),
            ),
          ],
        ),
      ),
    ),
  );
}
