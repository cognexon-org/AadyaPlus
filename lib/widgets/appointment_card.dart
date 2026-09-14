import 'package:aadya_plus/models/appointment.dart';
import 'package:aadya_plus/screens/appointments/appointment_details_screen.dart';
import 'package:aadya_plus/screens/appointments/consultation_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final status = appointment.status.toLowerCase();
    final terminal = const ['completed', 'cancelled', 'rejected', 'no_show'].contains(status);
    final canAction = !terminal && appointment.dateTime.isAfter(DateTime.now());
    final typeColor = appointment.isVideo
        ? Colors.purple
        : appointment.appointmentType == 'home'
            ? Colors.orange
            : Colors.blue;
    final typeIcon = appointment.isVideo
        ? Icons.videocam
        : appointment.appointmentType == 'home'
            ? Icons.home
            : Icons.local_hospital;
    final typeLabel = appointment.isVideo
        ? 'Video Consultation'
        : appointment.appointmentType == 'home'
            ? 'Home Visit'
            : 'Clinic Visit';

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointment: appointment)),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _badge(status.toUpperCase(), AppConstants.getStatusColor(status)),
                  Text(
                    DateFormat('dd MMM yyyy').format(appointment.dateTime),
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
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
                        Text(appointment.doctorName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(appointment.specialty, style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.w700, fontSize: 12)),
                        const SizedBox(height: 3),
                        Text(appointment.hospital, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                    Text(appointment.startTime ?? DateFormat('hh:mm a').format(appointment.dateTime), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Icon(typeIcon, size: 16, color: typeColor),
                    const SizedBox(width: 6),
                    Expanded(child: Text(typeLabel)),
                    Text('₹${appointment.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppConstants.primaryColor)),
                  ],
                ),
              ),
              if (appointment.isVideo && !terminal) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ConsultationScreen(appointment: appointment)),
                    ),
                    icon: Icon(appointment.paymentRequired ? Icons.lock_outline : Icons.videocam_outlined),
                    label: Text(appointment.paymentRequired ? 'Pay & prepare consultation' : 'Open consultation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appointment.paymentRequired ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
              if (canAction) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: onReschedule, child: const Text('Reschedule'))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
    );
  }
}
