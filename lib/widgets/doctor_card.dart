import 'package:flutter/material.dart';
import 'package:aadya_plus/models/doctor.dart';
import 'package:aadya_plus/utils/constants.dart';

class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;

  const DoctorCard({super.key, required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: doctor.professionalType == 'physio'
                          ? [Colors.green.shade400, Colors.green.shade700]
                          : [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        doctor.name.isNotEmpty ? doctor.name[0].toUpperCase() : 'D',
                        style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                doctor.name,
                                style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (doctor.verificationStatus == 'approved')
                              Icon(Icons.verified, size: 14, color: AppConstants.primaryColor),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                doctor.specialty,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppConstants.primaryColor,
                                ),
                              ),
                            ),
                            if (doctor.professionalType == 'physio') ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Physio',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 10, color: Colors.grey.shade400),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                doctor.hospital,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Bottom row: Rating + Distance + Fee
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    // Rating
                    Icon(Icons.star_rounded, size: 13, color: Colors.amber.shade600),
                    const SizedBox(width: 2),
                    Text(
                      doctor.rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    Text(
                      ' (${doctor.reviews})',
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                    ),
                    const SizedBox(width: 8),
                    // Experience
                    Icon(Icons.work_outline, size: 11, color: Colors.grey.shade400),
                    const SizedBox(width: 2),
                    Text(
                      '${doctor.experience}y exp',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    // Distance badge (if available)
                    if (doctor.distance != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.near_me, size: 10, color: Colors.blue.shade600),
                            const SizedBox(width: 2),
                            Text(
                              '${doctor.distance!.toStringAsFixed(1)}km',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Fee
                    Text(
                      '₹${doctor.consultationFee.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
