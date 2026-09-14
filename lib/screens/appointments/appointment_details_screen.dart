import 'package:aadya_plus/models/appointment.dart';
import 'package:aadya_plus/models/doctor.dart';
import 'package:aadya_plus/providers/appointment_provider.dart';
import 'package:aadya_plus/screens/appointments/consultation_screen.dart';
import 'package:aadya_plus/screens/appointments/prescription_details_screen.dart';
import 'package:aadya_plus/screens/chat/chat_screen.dart';
import 'package:aadya_plus/screens/payments/payment_checkout_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AppointmentDetailsScreen extends StatefulWidget {
  final Appointment appointment;

  const AppointmentDetailsScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailsScreen> createState() => _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  late String _paymentStatus;

  @override
  void initState() {
    super.initState();
    _paymentStatus = widget.appointment.paymentStatus;
  }

  bool get _isPaid => _paymentStatus == 'paid' || widget.appointment.totalAmount <= 0;

  void _openChat() {
    final stubDoctor = Doctor(
      id: widget.appointment.doctorId,
      name: widget.appointment.doctorName,
      specialty: widget.appointment.specialty,
      hospital: widget.appointment.hospital,
      rating: 5.0,
      reviews: 0,
      consultationFee: widget.appointment.consultationFee,
      experience: 0,
      imageUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.appointment.doctorName)}',
      description: '',
      languages: const [],
      availability: const {},
      professionalType: widget.appointment.professionalType,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(doctor: stubDoctor, appointmentId: widget.appointment.id),
      ),
    );
  }

  Future<void> _openGoogleMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.appointment.hospital)}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _pay() async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentCheckoutScreen(
          entityType: 'appointment',
          entityId: widget.appointment.id,
          title: 'Consultation with ${widget.appointment.doctorName}',
          expectedAmount: widget.appointment.totalAmount,
        ),
      ),
    );
    if (paid == true && mounted) {
      setState(() => _paymentStatus = 'paid');
      await context.read<AppointmentProvider>().loadAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final statusColor = AppConstants.getStatusColor(appointment.status);
    final dateStr = DateFormat('dd/MM/yyyy').format(appointment.dateTime.toLocal());
    final timeStr = DateFormat('hh:mm a').format(appointment.dateTime.toLocal());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        title: Text(
          'Appointment Details',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppConstants.textColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
                      _badge(appointment.status.toUpperCase(), statusColor),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoCol('Date', dateStr, Iconsax.calendar),
                      _infoCol('Time', timeStr, Iconsax.clock),
                      _infoCol(
                        'Type',
                        appointment.isVideo ? 'VIDEO' : appointment.appointmentType.toUpperCase(),
                        appointment.isVideo ? Iconsax.video : Iconsax.hospital,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Professional Information', style: _sectionStyle()),
            const SizedBox(height: 12),
            _card(
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: AppConstants.primaryColor,
                        child: Text(
                          appointment.doctorName.isNotEmpty ? appointment.doctorName[0] : 'D',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(appointment.doctorName, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(appointment.specialty, style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: _openChat, icon: const Icon(Iconsax.messages_2, color: AppConstants.primaryColor)),
                    ],
                  ),
                  const Divider(height: 26),
                  _detailRow('Hospital/Clinic', appointment.hospital),
                  const SizedBox(height: 8),
                  _detailRow('Symptoms', appointment.symptoms ?? 'N/A'),
                  const SizedBox(height: 8),
                  _detailRow('Reason', appointment.reason ?? 'N/A'),
                  if (!appointment.isVideo) ...[
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _openGoogleMaps,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Iconsax.location5, color: AppConstants.primaryColor),
                            SizedBox(width: 10),
                            Expanded(child: Text('View clinic location on Google Maps')),
                            Icon(Iconsax.routing, color: AppConstants.primaryColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (appointment.isVideo && !appointment.isTerminal) ...[
              const SizedBox(height: 20),
              Text('Video Consultation', style: _sectionStyle()),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ConsultationScreen(appointment: appointment)),
                  ),
                  icon: Icon(_isPaid ? Icons.videocam_outlined : Icons.lock_outline),
                  label: Text(_isPaid ? 'Open waiting room' : 'Pay & prepare consultation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPaid ? Colors.green : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
            if (appointment.prescriptionId != null && appointment.prescriptionId!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Medical Documents', style: _sectionStyle()),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrescriptionDetailsScreen(prescriptionId: appointment.prescriptionId!),
                    ),
                  ),
                  icon: const Icon(Iconsax.document_text_1),
                  label: const Text('View e-prescription'),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Payment Details', style: _sectionStyle()),
            const SizedBox(height: 12),
            _card(
              child: Column(
                children: [
                  _detailRow('Consultation Fee', '₹${appointment.consultationFee.toStringAsFixed(2)}'),
                  const Divider(height: 24),
                  _detailRow('Total', '₹${appointment.totalAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 10),
                  _detailRow('Payment Status', _isPaid ? 'PAID' : _paymentStatus.toUpperCase()),
                  if (!_isPaid && appointment.totalAmount > 0 && !appointment.isTerminal) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _pay,
                        child: const Text('Pay now'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  TextStyle _sectionStyle() => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppConstants.textColor,
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: child,
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _infoCol(String label, String value, IconData icon) => Column(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      );

  Widget _detailRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(
            flex: 3,
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      );
}
