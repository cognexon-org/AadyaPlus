import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aadya_plus/models/doctor.dart';
import 'package:aadya_plus/providers/appointment_provider.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:aadya_plus/services/api_client.dart' as http;

class BookAppointmentScreen extends StatefulWidget {
  final Doctor doctor;

  const BookAppointmentScreen({super.key, required this.doctor});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedSlot;
  String _selectedType = 'clinic';
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  List<Map<String, dynamic>> _availableSlots = [];
  bool _loadingSlots = false;
  bool _isBooking = false;

  // Location state for home visits
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;
  String? _locationError;

  @override
  void dispose() {
    _symptomsController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  List<DateTime> _generateDateOptions() {
    final dates = <DateTime>[];
    final today = DateTime.now();
    for (int i = 1; i <= 14; i++) {
      dates.add(today.add(Duration(days: i)));
    }
    return dates;
  }

  double _getConsultationFee() {
    switch (_selectedType) {
      case 'video':
        return widget.doctor.videoCallFee > 0 
            ? widget.doctor.videoCallFee 
            : widget.doctor.consultationFee;
      case 'home':
        return widget.doctor.homeVisitFee > 0 
            ? widget.doctor.homeVisitFee 
            : widget.doctor.consultationFee;
      default:
        return widget.doctor.consultationFee;
    }
  }

  Future<void> _fetchSlots() async {
    if (_selectedDate == null) return;
    
    setState(() {
      _loadingSlots = true;
      _selectedSlot = null;
      _availableSlots = [];
    });

    final provider = Provider.of<AppointmentProvider>(context, listen: false);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    
    final slots = await provider.fetchAvailableSlots(
      professionalId: widget.doctor.id,
      professionalType: widget.doctor.professionalType,
      date: dateStr,
      type: _selectedType,
    );

    setState(() {
      _availableSlots = slots;
      _loadingSlots = false;
    });
  }

  // ───── Location Methods ─────

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isFetchingLocation = false;
          _locationError = 'Location services are disabled. Please enable GPS.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isFetchingLocation = false;
            _locationError = 'Location permission denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isFetchingLocation = false;
          _locationError = 'Location permanently denied. Enable in Settings.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      // Reverse geocode to get address
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get location. Please try again.';
      });
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      // Use Nominatim for reverse geocoding (same as web frontend)
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'AadyaPlus/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          _addressController.text = data['display_name'];
        } else {
          _addressController.text = 'Location at ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
        }
      } else {
        _addressController.text = 'Location at ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      }
    } catch (e) {
      _addressController.text = 'Location at ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
  }

  // ───── Booking ─────

  Future<void> _bookAppointment() async {
    if (_selectedDate == null) {
      _showError('Please select a date');
      return;
    }
    if (_selectedSlot == null) {
      _showError('Please select a time slot');
      return;
    }
    if (_symptomsController.text.trim().isEmpty) {
      _showError('Please describe your symptoms');
      return;
    }

    // Validate location for home visits
    if (_selectedType == 'home') {
      if (_latitude == null || _longitude == null) {
        _showError('Please provide your location for a home visit');
        return;
      }
      if (_addressController.text.trim().isEmpty) {
        _showError('Please provide your address for the home visit');
        return;
      }
    }

    setState(() => _isBooking = true);

    final provider = Provider.of<AppointmentProvider>(context, listen: false);

    try {
      await provider.bookAppointment(
        doctorId: widget.doctor.id,
        doctorName: widget.doctor.name,
        specialty: widget.doctor.specialty,
        hospital: widget.doctor.hospital,
        dateTime: _selectedDate!,
        consultationFee: _getConsultationFee(),
        appointmentType: _selectedType,
        professionalType: widget.doctor.professionalType,
        startTime: _selectedSlot!['startTime'],
        symptoms: _symptomsController.text.trim(),
        reason: _notesController.text.trim(),
        address: _selectedType == 'home' ? _addressController.text.trim() : null,
        locationCoordinates: _selectedType == 'home' && _longitude != null && _latitude != null
            ? [_longitude!, _latitude!]  // GeoJSON: [lng, lat]
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to book: $e');
      }
    }

    if (mounted) {
      setState(() => _isBooking = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateOptions = _generateDateOptions();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Book Appointment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [AppConstants.primaryColor.withOpacity(0.1), AppConstants.primaryColor.withOpacity(0.2)],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 24,
                        color: AppConstants.primaryColor.withOpacity(0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.doctor.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.doctor.specialty,
                          style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Consultation Type
            const Text(
              'Consultation Type',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B), letterSpacing: -0.2),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTypeCard(Icons.business, 'Clinic', 'clinic', 
                    '₹${widget.doctor.consultationFee}', Colors.blue),
                const SizedBox(width: 10),
                _buildTypeCard(Icons.videocam, 'Video', 'video',
                    '₹${widget.doctor.videoCallFee > 0 ? widget.doctor.videoCallFee : widget.doctor.consultationFee}', Colors.purple),
                const SizedBox(width: 10),
                _buildTypeCard(Icons.home, 'Home', 'home',
                    '₹${widget.doctor.homeVisitFee > 0 ? widget.doctor.homeVisitFee : widget.doctor.consultationFee}', Colors.orange),
              ],
            ),

            const SizedBox(height: 28),

            // Select Date
            const Text(
              'Select Date',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B), letterSpacing: -0.2),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 85,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: dateOptions.length,
                itemBuilder: (context, index) {
                  final date = dateOptions[index];
                  final isSelected = _selectedDate != null && 
                      DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(_selectedDate!);
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = date);
                      _fetchSlots();
                    },
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppConstants.primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppConstants.primaryColor : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('EEE').format(date).toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected ? Colors.white70 : Colors.grey[500],
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd').format(date),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(date),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white70 : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 28),

            // Time Slots
            const Text(
              'Available Slots',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B), letterSpacing: -0.2),
            ),
            const SizedBox(height: 12),
            
            if (_selectedDate == null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Please select a date first',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ),
              )
            else if (_loadingSlots)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (_availableSlots.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No available slots for this date. Try another date or consultation type.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availableSlots.map((slot) {
                  final isSelected = _selectedSlot == slot;
                  final start = slot['startTime'] ?? '';
                  final end = slot['endTime'] ?? '';
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSlot = slot),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppConstants.primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppConstants.primaryColor : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        '$start - $end',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 28),

            // ─────── HOME VISIT LOCATION SECTION ───────
            if (_selectedType == 'home') ...[
              const Text(
                'Visit Location',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B), letterSpacing: -0.2),
              ),
              const SizedBox(height: 6),
              Text(
                'We need your location so the doctor can visit you at home.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 14),

              // Get Location Button
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isFetchingLocation ? null : _fetchCurrentLocation,
                      icon: _isFetchingLocation
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(
                        _isFetchingLocation ? 'Fetching...' : 'Use Current Location',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.only(left: 12, right: 8, top: 12, bottom: 12),
                        alignment: Alignment.centerLeft,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (_latitude == null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _locationError = null;
                            _latitude = 0;
                            _longitude = 0;
                          });
                        },
                        icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                        label: const Text(
                          'Enter Manually',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.only(left: 12, right: 8, top: 12, bottom: 12),
                          alignment: Alignment.centerLeft,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Location Error
              if (_locationError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 18, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationError!,
                          style: TextStyle(fontSize: 12, color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Location Captured — Address Input
              if (_latitude != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppConstants.primaryColor.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location status indicator
                      if (_latitude != 0 && _longitude != 0)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check, size: 14, color: Colors.green[700]),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location captured',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green[700]),
                                  ),
                                  Text(
                                    '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                            // Re-fetch button
                            GestureDetector(
                              onTap: _fetchCurrentLocation,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.refresh, size: 16, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),

                      if (_latitude != 0 && _longitude != 0) const SizedBox(height: 14),

                      // Address text field
                      const Text(
                        'Detailed Address *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'House no., Street, Area, Landmark...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppConstants.primaryColor, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please verify/edit the address for accurate home visit.',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),
            ],

            // Symptoms
            const Text(
              'Describe Your Symptoms *',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B), letterSpacing: -0.2),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _symptomsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'E.g. Headache, Fever, Back pain...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppConstants.primaryColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Additional Notes (Optional)
            const Text(
              'Additional Notes (Optional)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B), letterSpacing: -0.2),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Any additional information...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppConstants.primaryColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Fee Summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.primaryColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Consultation Fee', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      Text('₹${_getConsultationFee()}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                      Text(
                        '₹${_getConsultationFee()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Book Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _bookAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  disabledBackgroundColor: AppConstants.primaryColor.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isBooking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Confirm Booking',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(IconData icon, String label, String type, String fee, Color color) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _selectedSlot = null;
          });
          if (_selectedDate != null) _fetchSlots();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey[500], size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fee,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? color : Colors.grey[500],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
