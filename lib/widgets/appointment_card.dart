import 'package:flutter/material.dart';
import 'package:aadya_plus/models/appointment.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:aadya_plus/screens/appointments/video_call_screen.dart';
import 'package:aadya_plus/screens/appointments/appointment_details_screen.dart';
import 'package:intl/intl.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onCancel,
    required this.onReschedule,
  });

  Color getStatusColor(String status) {
    return AppConstants.getStatusColor(status);
  }

  /// Determines video call join button state, matching web version logic
  Map<String, dynamic>? _getVideoMeetStatus() {
    if (appointment.appointmentType.toLowerCase() != 'video' || 
        appointment.meetingLink == null || 
        appointment.meetingLink!.isEmpty) {
      return null;
    }
    
    if (appointment.status.toLowerCase() == 'completed' || 
        appointment.status.toLowerCase() == 'cancelled') {
      return {'state': 'ended'};
    }

    final now = DateTime.now();
    final diffInMinutes = appointment.dateTime.difference(now).inMinutes;

    // If meeting is more than 60 minutes past, it's ended
    if (diffInMinutes < -60) {
      return {'state': 'ended'};
    }

    // If within 10 minutes or past start time, allow joining
    if (diffInMinutes <= 10) {
      return {'state': 'available', 'link': appointment.meetingLink};
    }

    // Still waiting
    String timeText;
    final diffInHours = diffInMinutes ~/ 60;
    final remainingMins = diffInMinutes % 60;
    if (diffInHours > 24) {
      timeText = '${diffInHours ~/ 24} days';
    } else if (diffInHours > 0) {
      timeText = '${diffInHours}h ${remainingMins}m';
    } else {
      timeText = '$remainingMins mins';
    }
    return {'state': 'waiting', 'timeText': timeText};
  }

  void _openVideoCall(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          meetingLink: url,
          doctorName: appointment.doctorName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isCancelled = appointment.status.toLowerCase() == 'cancelled';
    bool isCompleted = appointment.status.toLowerCase() == 'completed';
    bool canAction = !isCancelled && !isCompleted && appointment.dateTime.isAfter(DateTime.now());

    IconData typeIcon = Icons.local_hospital;
    String typeLabel = 'Clinic Visit';
    Color typeColor = Colors.blue;

    if (appointment.appointmentType.toLowerCase() == 'video') {
      typeIcon = Icons.videocam;
      typeLabel = 'Video Consultation';
      typeColor = Colors.purple;
    } else if (appointment.appointmentType.toLowerCase() == 'home') {
      typeIcon = Icons.home;
      typeLabel = 'Home Visit';
      typeColor = Colors.orange;
    }

    final videoStatus = _getVideoMeetStatus();

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AppointmentDetailsScreen(appointment: appointment),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Status + Date row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: getStatusColor(appointment.status).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: getStatusColor(appointment.status)),
                      const SizedBox(width: 4),
                      Text(
                        appointment.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: getStatusColor(appointment.status),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(appointment.dateTime),
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Doctor info row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      appointment.doctorName.isNotEmpty ? appointment.doctorName[0].toUpperCase() : 'D',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.doctorName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        appointment.specialty,
                        style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            appointment.hospital,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Details bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    appointment.startTime ?? DateFormat('hh:mm a').format(appointment.dateTime),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 16, color: Colors.grey.shade300),
                  const SizedBox(width: 12),
                  Icon(typeIcon, size: 16, color: typeColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      typeLabel,
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                  Text(
                    '₹${appointment.consultationFee.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppConstants.primaryColor),
                  ),
                ],
              ),
            ),

            // Reason
            if (appointment.reason != null && appointment.reason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reason: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    Expanded(
                      child: Text(
                        appointment.reason!,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Symptoms
            if (appointment.symptoms != null && appointment.symptoms!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 15, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Symptoms: ${appointment.symptoms!}',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Video Call Join Button (matching web version's Jitsi logic)
            if (videoStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Builder(
                  builder: (context) {
                    if (videoStatus['state'] == 'available') {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openVideoCall(context, videoStatus['link']),
                          icon: const Icon(Icons.videocam, size: 18),
                          label: const Text('Join Video Consultation', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      );
                    } else if (videoStatus['state'] == 'waiting') {
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('You can join the meeting during your scheduled slot. (Available in ${videoStatus['timeText']})'),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              },
                              icon: Icon(Icons.schedule, size: 18, color: Colors.grey.shade600),
                              label: Text(
                                'Join in ${videoStatus['timeText']}',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: TextButton.icon(
                              onPressed: () => _openVideoCall(context, appointment.meetingLink!),
                              icon: const Icon(Icons.link, size: 14),
                              label: const Text('Open Meet Link', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue.shade600,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // ended
                      return SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: null,
                          icon: Icon(Icons.videocam_off, size: 18, color: Colors.grey.shade400),
                          label: Text('Meeting Ended', style: TextStyle(color: Colors.grey.shade400)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade200),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),

            // Action Buttons
            if (canAction)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReschedule,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Reschedule', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade100),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
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
