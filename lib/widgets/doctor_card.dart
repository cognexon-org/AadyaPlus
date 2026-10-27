import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/ui/app_ui.dart';
import '../models/doctor.dart';

/// A doctor or physio in a list: who they are, how they can be seen, and
/// what it costs from.
class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;
  const DoctorCard({super.key, required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = doctor.isPhysio ? ModuleAccent.physio : ModuleAccent.doctor;
    final meta = [
      if (doctor.experience > 0) '${doctor.experience} yrs exp',
      if (doctor.qualifications.isNotEmpty) doctor.qualifications.take(2).join(', '),
    ].join(' · ');
    final place = [
      if (doctor.clinicName.isNotEmpty) doctor.clinicName,
      if (doctor.hospital.isNotEmpty) doctor.hospital,
    ].join(', ');
    return AppPressable(
      onTap: onTap,
      scale: 0.985,
      semanticLabel: '${doctor.name}, ${doctor.specialty}',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAvatar(
                    name: doctor.name,
                    imageUrl: doctor.imageUrl,
                    size: 62,
                    radius: 18,
                    color: accent.color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                doctor.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.sans(
                                  fontSize: AppType.title,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textStrong,
                                ),
                              ),
                            ),
                            if (doctor.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.badgeCheck, size: 15, color: AppColors.brand),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doctor.specialty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(
                            fontSize: AppType.small,
                            fontWeight: FontWeight.w600,
                            color: accent.color,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.sans(
                              fontSize: AppType.caption,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (doctor.reviews > 0)
                              _Meta(
                                icon: LucideIcons.star,
                                iconColor: const Color(0xFFF59E0B),
                                text: '${doctor.rating.toStringAsFixed(1)} (${doctor.reviews})',
                              ),
                            if (doctor.distance != null)
                              _Meta(
                                icon: LucideIcons.navigation,
                                text: doctor.distance! < 1
                                    ? '${(doctor.distance! * 1000).round()} m'
                                    : '${doctor.distance!.toStringAsFixed(1)} km',
                              ),
                            if (place.isNotEmpty)
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 170),
                                child: _Meta(icon: LucideIcons.mapPin, text: place),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  if (doctor.clinicEnabled) _VisitIcon(LucideIcons.building2, 'Clinic', accent),
                  if (doctor.videoEnabled) _VisitIcon(LucideIcons.video, 'Video', accent),
                  if (doctor.homeEnabled) _VisitIcon(LucideIcons.house, 'Home', accent),
                  const Spacer(),
                  if (doctor.fromFee > 0) ...[
                    Text(
                      'from ',
                      style: AppType.sans(
                        fontSize: AppType.caption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      appRupees(doctor.fromFee),
                      style: AppType.sans(
                        fontSize: AppType.title,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textStrong,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.color,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      'Book',
                      style: AppType.sans(
                        fontSize: AppType.small,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;
  const _Meta({required this.icon, required this.text, this.iconColor});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12.5, color: iconColor ?? AppColors.textTertiary),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.sans(
            fontSize: AppType.caption,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );
}

class _VisitIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final ModuleAccent accent;
  const _VisitIcon(this.icon, this.label, this.accent);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Tooltip(
      message: '$label consultation',
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: accent.veryLight,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 15, color: accent.color),
      ),
    ),
  );
}
