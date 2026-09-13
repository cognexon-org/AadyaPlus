import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:aadya_plus/models/appointment.dart';
import 'package:aadya_plus/models/doctor.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:aadya_plus/screens/chat/chat_screen.dart';
import 'package:aadya_plus/screens/appointments/prescription_details_screen.dart';

class AppointmentDetailsScreen extends StatefulWidget {
  final Appointment appointment;

  const AppointmentDetailsScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailsScreen> createState() => _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  Color _getStatusColor(String status) {
    if (status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'accepted') return Colors.green;
    if (status.toLowerCase() == 'pending') return Colors.orange;
    if (status.toLowerCase() == 'cancelled') return Colors.red;
    return AppConstants.primaryColor;
  }

  void _openChat(BuildContext context) {
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
      languages: [],
      availability: {},
      professionalType: widget.appointment.professionalType,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          doctor: stubDoctor,
          appointmentId: widget.appointment.id,
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps() async {
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.appointment.hospital)}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _joinVideoCall() async {
    if (widget.appointment.meetingLink != null && widget.appointment.meetingLink!.isNotEmpty) {
      final uri = Uri.parse(widget.appointment.meetingLink!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.appointment.status.toLowerCase();
    final statusColor = _getStatusColor(status);
    
    // Formatting date and time
    final dateStr = DateFormat('dd/MM/yyyy').format(widget.appointment.dateTime.toLocal());
    final timeStr = DateFormat('hh:mm a').format(widget.appointment.dateTime.toLocal());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        title: Text('Appointment Details', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: Colors.white, 
        foregroundColor: AppConstants.textColor, 
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and Date Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(status.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoCol('Date', dateStr, Iconsax.calendar),
                      _buildInfoCol('Time', timeStr, Iconsax.clock),
                      _buildInfoCol('Type', widget.appointment.appointmentType.toUpperCase(), 
                        widget.appointment.appointmentType == 'teleconsultation' ? Iconsax.video : Iconsax.hospital),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Professional Info
            Text('Professional Information', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppConstants.textColor)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: const BoxDecoration(color: AppConstants.primaryColor, shape: BoxShape.circle),
                        child: Center(child: Text(widget.appointment.doctorName[0], style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.appointment.doctorName, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppConstants.textColor)),
                            Text(widget.appointment.specialty, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _openChat(context), 
                            icon: const Icon(Iconsax.messages_2, color: AppConstants.primaryColor)),
                        ],
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  _buildDetailRow('Hospital/Clinic', widget.appointment.hospital),
                  const SizedBox(height: 8),
                  _buildDetailRow('Symptoms', widget.appointment.symptoms ?? 'N/A'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Reason', widget.appointment.reason ?? 'N/A'),
                  
                  if (widget.appointment.appointmentType != 'teleconsultation') ...[
                    const SizedBox(height: 12),
                    Text('Clinic Location', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _openGoogleMaps,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppConstants.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2))),
                        child: Row(
                          children: [
                            const Icon(Iconsax.location5, color: AppConstants.primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.appointment.hospital, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppConstants.primaryColor)),
                                  const SizedBox(height: 2),
                                  Text('Tap to view on Google Maps', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppConstants.primaryColor.withOpacity(0.7))),
                                ],
                              ),
                            ),
                            const Icon(Iconsax.routing, color: AppConstants.primaryColor, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (widget.appointment.appointmentType == 'teleconsultation' && widget.appointment.meetingLink != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppConstants.primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2))),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _joinVideoCall,
                            child: const Icon(Iconsax.video5, color: AppConstants.primaryColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _joinVideoCall,
                              child: Text('Join Video Meeting', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppConstants.primaryColor)),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.appointment.meetingLink!));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard'), behavior: SnackBarBehavior.floating));
                            },
                            icon: const Icon(Iconsax.copy, color: AppConstants.primaryColor, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _joinVideoCall,
                            child: const Icon(Iconsax.arrow_right_3, color: AppConstants.primaryColor, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Prescription Info
            if (widget.appointment.prescriptionId != null && widget.appointment.prescriptionId!.isNotEmpty) ...[
              Text('Medical Documents', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppConstants.textColor)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => PrescriptionDetailsScreen(prescriptionId: widget.appointment.prescriptionId!))
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor, 
                    borderRadius: BorderRadius.circular(16), 
                    boxShadow: [
                      BoxShadow(color: AppConstants.primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Iconsax.document_text_1, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('View Prescription', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text('Read doctor\'s advice & medicines', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                          ],
                        ),
                      ),
                      const Icon(Iconsax.arrow_right_3, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Payment Info
            Text('Payment Details', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppConstants.textColor)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  _buildDetailRow('Consultation Fee', '₹${widget.appointment.consultationFee}', valueWeight: FontWeight.w700),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  _buildDetailRow('Total Paid', '₹${widget.appointment.consultationFee}', valueColor: AppConstants.primaryColor, valueWeight: FontWeight.w700, valueSize: 16),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppConstants.textColor)),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, FontWeight? valueWeight, double? valueSize}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600)),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value, 
            style: GoogleFonts.plusJakartaSans(
              fontSize: valueSize ?? 13, 
              fontWeight: valueWeight ?? FontWeight.w500, 
              color: valueColor ?? AppConstants.textColor
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
