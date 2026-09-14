import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:intl/intl.dart';
import 'package:aadya_plus/models/appointment.dart';
import 'package:aadya_plus/providers/appointment_provider.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:aadya_plus/services/secure_storage_service.dart';

class RescheduleAppointmentScreen extends StatefulWidget {
  final Appointment appointment;

  const RescheduleAppointmentScreen({super.key, required this.appointment});

  @override
  State<RescheduleAppointmentScreen> createState() =>
      _RescheduleAppointmentScreenState();
}

class _RescheduleAppointmentScreenState
    extends State<RescheduleAppointmentScreen> {
  bool _isLoading = false;
  bool _isSlotsLoading = false;
  bool _isRescheduling = false;

  Map<String, dynamic>? _doctor;
  List<Map<String, dynamic>> _availableSlots = [];
  String? _selectedDate;
  Map<String, dynamic>? _selectedSlot;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfessionalDetails();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Generate the next 14 days (excluding today) for date selection
  List<Map<String, dynamic>> _generateDateOptions() {
    final dates = <Map<String, dynamic>>[];
    final today = DateTime.now();

    for (int i = 1; i <= 14; i++) {
      final date = today.add(Duration(days: i));
      dates.add({
        'value': DateFormat('yyyy-MM-dd').format(date),
        'weekday': DateFormat('EEE').format(date),
        'day': DateFormat('d').format(date),
        'month': DateFormat('MMM').format(date),
        'isWeekend': date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
      });
    }
    return dates;
  }

  /// Fetch doctor / physio details (mirrors web: GET /<type>/<id>)
  Future<void> _fetchProfessionalDetails() async {
    setState(() => _isLoading = true);

    try {
      final profType = widget.appointment.professionalType;
      final profId = widget.appointment.doctorId;
      if (profId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final url = '${AppConstants.baseUrl}/$profType/$profId';
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _doctor = data['doctor'] ?? data['physio'] ?? data['pathology'] ?? data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching professional: $e');
    }

    setState(() => _isLoading = false);
  }

  /// Fetch available slots for the selected date
  Future<void> _fetchAvailableSlots() async {
    if (_selectedDate == null) return;

    setState(() {
      _isSlotsLoading = true;
      _availableSlots = [];
      _selectedSlot = null;
    });

    try {
      final provider = Provider.of<AppointmentProvider>(context, listen: false);
      final slots = await provider.fetchAvailableSlots(
        professionalId: widget.appointment.doctorId,
        professionalType: widget.appointment.professionalType,
        date: _selectedDate!,
        type: widget.appointment.appointmentType,
      );
      setState(() => _availableSlots = slots);
    } catch (e) {
      debugPrint('Error fetching slots: $e');
    }

    setState(() => _isSlotsLoading = false);
  }

  /// POST /appointment/:id/reschedule  — mirrors web version exactly
  Future<void> _handleReschedule() async {
    if (_selectedSlot == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a new date and time slot'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isRescheduling = true);

    try {
      final token = await SecureStorageService.instance.readToken();

      final rescheduleData = {
        'newDate': _selectedDate,
        'newTime': _selectedSlot!['startTime'],
        'reason': _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : 'Rescheduled by patient',
      };

      final response = await http.post(
        Uri.parse('${AppConstants.appointmentsUrl}/${widget.appointment.id}/reschedule'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(rescheduleData),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Reload appointments in provider
        if (mounted) {
          Provider.of<AppointmentProvider>(context, listen: false).loadAppointments();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment rescheduled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception(responseData['error'] ?? 'Failed to reschedule appointment');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reschedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _isRescheduling = false);
  }

  @override
  Widget build(BuildContext context) {
    final dateOptions = _generateDateOptions();
    final doctorName = _doctor?['name']?.toString() ?? widget.appointment.doctorName;
    final specialty = (_doctor?['specialization'] is List && (_doctor!['specialization'] as List).isNotEmpty)
        ? _doctor!['specialization'][0].toString()
        : widget.appointment.specialty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reschedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('Choose a new date & time', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),

      // Bottom confirm button
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
            ],
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_selectedSlot != null && !_isRescheduling) ? _handleReschedule : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade500,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isRescheduling
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Confirm Reschedule', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Current appointment info ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB), // amber-50
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)), // amber-200
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Appointment',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E), fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.amber.shade800),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('dd MMM yyyy').format(widget.appointment.dateTime),
                              style: TextStyle(fontSize: 13, color: Colors.amber.shade800, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.access_time, size: 14, color: Colors.amber.shade800),
                            const SizedBox(width: 6),
                            Text(
                              widget.appointment.startTime ?? DateFormat('HH:mm').format(widget.appointment.dateTime),
                              style: TextStyle(fontSize: 13, color: Colors.amber.shade800, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Doctor card ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppConstants.primaryColor, AppConstants.secondaryColor]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(doctorName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                              const SizedBox(height: 2),
                              Text(specialty, style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.w700, fontSize: 12)),
                              if (_doctor?['clinicAddress']?['city'] != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 3),
                                    Text(
                                      _doctor!['clinicAddress']['city'].toString(),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Date selection ──
                  const Text('Select New Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: dateOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final date = dateOptions[index];
                        final isSelected = _selectedDate == date['value'];
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedDate = date['value']);
                            _fetchAvailableSlots();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 72,
                            decoration: BoxDecoration(
                              color: isSelected ? AppConstants.primaryColor : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppConstants.primaryColor : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: AppConstants.primaryColor.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
                                  : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  date['weekday'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white70 : Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  date['day'],
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  date['month'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white70 : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Time slots ──
                  if (_selectedDate != null) ...[
                    Row(
                      children: [
                        const Text('Available Slots', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                        const Spacer(),
                        Text(
                          DateFormat('EEEE, d MMM').format(DateTime.parse(_selectedDate!)),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isSlotsLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_availableSlots.isEmpty)
                      _buildNoSlotsState()
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _availableSlots.length,
                        itemBuilder: (context, index) {
                          final slot = _availableSlots[index];
                          final isSelected = _selectedSlot?['startTime'] == slot['startTime'];
                          return GestureDetector(
                            onTap: () => setState(() => _selectedSlot = slot),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? AppConstants.primaryColor : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppConstants.primaryColor : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: AppConstants.primaryColor.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    slot['startTime']?.toString() ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (slot['endTime'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'to ${slot['endTime']}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected ? Colors.white70 : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],

                  // ── Reason ──
                  const Text('Reason (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    cursorColor: AppConstants.primaryColor,
                    decoration: InputDecoration(
                      hintText: 'E.g., Unexpected conflict, feeling better...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.all(14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppConstants.primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Summary card ──
                  if (_selectedDate != null || _selectedSlot != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF), // sky-50
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBAE6FD)), // sky-200
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reschedule Summary',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0369A1)),
                          ),
                          const SizedBox(height: 12),
                          _summaryRow('Doctor', doctorName),
                          _summaryRow('Type', widget.appointment.appointmentType),
                          if (_selectedDate != null)
                            _summaryRow(
                              'New Date',
                              DateFormat('EEE, d MMM yyyy').format(DateTime.parse(_selectedDate!)),
                            ),
                          if (_selectedSlot != null)
                            _summaryRow('New Time', _selectedSlot!['startTime']?.toString() ?? ''),
                        ],
                      ),
                    ),

                  const SizedBox(height: 100), // space for bottom button
                ],
              ),
            ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0369A1))),
        ],
      ),
    );
  }

  Widget _buildNoSlotsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.schedule, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No available slots for this date',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'Please select another date',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
