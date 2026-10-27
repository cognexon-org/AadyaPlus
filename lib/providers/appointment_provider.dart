import 'package:aadya_plus/core/utils/server_dates.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:aadya_plus/models/appointment.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:aadya_plus/services/secure_storage_service.dart';

class AppointmentProvider with ChangeNotifier {
  List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _error;

  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AppointmentProvider() {
    loadAppointments();
  }

  Future<void> loadAppointments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await SecureStorageService.instance.readToken();

      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Newest first, so a long history never pushes upcoming visits off
      // the page (the server's default is the oldest 20).
      final response = await http.get(
        Uri.parse('${AppConstants.appointmentsUrl}?limit=100&sort=appointmentDate:desc'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final List<dynamic> aptDocs = responseData['appointments'] ?? [];
        
        _appointments = aptDocs.map((doc) {
          final professionalType = doc['professionalType']?.toString() ?? 'doctor';
          
          String doctorName = 'Unknown';
          String docId = '';
          String docSpecialty = 'General';
          String hospital = '';
          String clinicName = '';
          String clinicAddress = '';
          String imageUrl = '';
          
          if (doc['doctorId'] != null && doc['doctorId'] is Map && professionalType == 'doctor') {
            docId = doc['doctorId']['_id']?.toString() ?? '';
            doctorName = doc['doctorId']['name']?.toString() ?? 'Unknown Doctor';
            docSpecialty = (doc['doctorId']['specialization'] != null && (doc['doctorId']['specialization'] as List).isNotEmpty) 
                ? doc['doctorId']['specialization'][0].toString() 
                : 'General';
            clinicName = doc['doctorId']['clinicName']?.toString() ?? '';
            imageUrl = doc['doctorId']['profileImage']?.toString() ?? '';
            if (doc['doctorId']['clinicAddress'] is Map) {
              final a = doc['doctorId']['clinicAddress'] as Map;
              hospital = a['city']?.toString() ?? '';
              clinicAddress = [a['address'], a['locality'], a['city']]
                  .where((e) => e != null && e.toString().trim().isNotEmpty)
                  .join(', ');
            }
          } else if (doc['physioId'] != null && doc['physioId'] is Map && professionalType == 'physio') {
            docId = doc['physioId']['_id']?.toString() ?? '';
            doctorName = doc['physioId']['name']?.toString() ?? 'Unknown Physio';
            final specs = doc['physioId']['specialization'];
            docSpecialty = specs is List && specs.isNotEmpty ? specs.first.toString() : 'Physiotherapy';
            imageUrl = doc['physioId']['profileImage']?.toString() ?? '';
            if (doc['physioId']['clinicAddress'] is Map) {
              final a = doc['physioId']['clinicAddress'] as Map;
              hospital = a['city']?.toString() ?? '';
              clinicAddress = [a['address'], a['city']]
                  .where((e) => e != null && e.toString().trim().isNotEmpty)
                  .join(', ');
            }
          }

          // The booked day is the server's local midnight; read it as the
          // intended calendar day, then add the clinic-local start time.
          final String? rawStartTime = doc['startTime']?.toString();
          final DateTime parsedDate =
              serverDayAt(doc['appointmentDate'], rawStartTime) ??
              DateTime.now();

          return Appointment(
            id: doc['_id']?.toString() ?? '',
            doctorId: docId,
            doctorName: doctorName,
            specialty: docSpecialty,
            hospital: hospital,
            patientName: (doc['patientId'] is Map) ? doc['patientId']['name']?.toString() ?? 'Me' : 'Me',
            dateTime: parsedDate,
            status: doc['status']?.toString() ?? 'pending',
            consultationFee: (doc['consultationFee'] is num) ? (doc['consultationFee'] as num).toDouble() : ((doc['totalAmount'] is num) ? (doc['totalAmount'] as num).toDouble() : 0.0),
            totalAmount: (doc['totalAmount'] is num) ? (doc['totalAmount'] as num).toDouble() : ((doc['consultationFee'] is num) ? (doc['consultationFee'] as num).toDouble() : 0.0),
            paymentStatus: doc['paymentStatus']?.toString() ?? 'pending',
            appointmentType: doc['type']?.toString() ?? 'clinic',
            symptoms: doc['symptoms'] != null && (doc['symptoms'] as List).isNotEmpty ? doc['symptoms'][0].toString() : null,
            createdAt: doc['createdAt'] != null ? DateTime.parse(doc['createdAt'].toString()) : DateTime.now(),
            meetingLink: doc['meetingLink']?.toString(),
            startTime: rawStartTime,
            reason: doc['reason']?.toString(),
            prescriptionId: doc['prescriptionId'] is Map ? doc['prescriptionId']['_id']?.toString() : doc['prescriptionId']?.toString(),
            consultationSessionId: doc['consultationSessionId'] is Map ? doc['consultationSessionId']['_id']?.toString() : doc['consultationSessionId']?.toString(),
            professionalType: professionalType,
            duration: doc['duration'] ?? 30,
            clinicName: clinicName,
            clinicAddress: clinicAddress,
            imageUrl: imageUrl,
            visitAddress: doc['address']?.toString() ?? '',
            symptomList: doc['symptoms'] is List
                ? (doc['symptoms'] as List).map((e) => e.toString()).toList()
                : const [],
            cancellationReason: doc['cancellationReason']?.toString(),
            rescheduleCount: (doc['rescheduleCount'] as num?)?.toInt() ?? 0,
          );
        }).toList();

      } else {
        _error = responseData['error'] ?? 'Failed to load appointments';
      }
    } catch (e) {
      _error = 'Network error: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> bookAppointment({
    required String doctorId,
    required String doctorName,
    required String specialty,
    required String hospital,
    required DateTime dateTime,
    required double consultationFee,
    required String appointmentType,
    required String professionalType,
    String? startTime,
    String? symptoms,
    String? reason,
    String? address,
    List<double>? locationCoordinates,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await SecureStorageService.instance.readToken();
      
      // Use provided startTime or derive from dateTime
      final String timeString = startTime ?? 
          "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";

      final Map<String, dynamic> body = {
        'professionalId': doctorId,
        'professionalType': professionalType,
        'appointmentDate': dateTime.toIso8601String().split('T')[0],
        'startTime': timeString,
        'type': appointmentType,
        'symptoms': symptoms != null && symptoms.isNotEmpty 
            ? symptoms.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
            : [],
        'reason': reason ?? '',
      };

      // Include location data for home visit appointments
      if (appointmentType == 'home') {
        if (address != null && address.isNotEmpty) {
          body['address'] = address;
        }
        if (locationCoordinates != null && locationCoordinates.length == 2) {
          body['location'] = {
            'type': 'Point',
            'coordinates': locationCoordinates, // [longitude, latitude]
          };
        }
      }

      final response = await http.post(
        Uri.parse(AppConstants.appointmentsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201 && responseData['success'] == true) {
         await loadAppointments();
      } else {
         throw Exception(responseData['error'] ?? 'Failed to book appointment');
      }

    } catch (e) {
      _error = 'Booking error: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Books a slot. Returns the new appointment's id and what's owed, so the
  /// confirmation can offer payment straight away.
  Future<BookingResult> book({
    required String professionalId,
    required String professionalType,
    required DateTime date,
    required String startTime,
    required String visit,
    List<String> symptoms = const [],
    String reason = '',
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{
      'professionalId': professionalId,
      'professionalType': professionalType,
      'appointmentDate':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'startTime': startTime,
      'type': visit,
      'symptoms': symptoms,
      'reason': reason,
      if (visit == 'home' && address != null) 'address': address,
      if (visit == 'home' && latitude != null && longitude != null)
        'location': {
          'type': 'Point',
          'coordinates': [longitude, latitude],
        },
    };
    final response = await http.post(
      Uri.parse(AppConstants.appointmentsUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    final data = response.body.trim().isEmpty ? <String, dynamic>{} : json.decode(response.body);
    if (response.statusCode != 201 || data['success'] != true) {
      throw Exception(data['error'] ?? data['message'] ?? 'Couldn’t book this slot');
    }
    final appointment = data['appointment'] is Map ? data['appointment'] as Map : const {};
    // Refresh the list in the background; the confirmation doesn't wait.
    loadAppointments();
    return BookingResult(
      appointmentId: (appointment['_id'] ?? '').toString(),
      amount: ((appointment['totalAmount'] ?? appointment['consultationFee'] ?? 0) as num).toDouble(),
      paymentRequired: data['paymentRequired'] == true,
    );
  }

  /// Moves an appointment to a new slot (the backend allows two moves).
  Future<void> reschedule(String appointmentId, DateTime at, {String reason = ''}) async {
    final response = await http.post(
      Uri.parse('${AppConstants.appointmentsUrl}/$appointmentId/reschedule'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'newDate':
            '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}',
        'newTime': '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
        'reason': reason.isEmpty ? 'Rescheduled by patient' : reason,
      }),
    );
    final data = response.body.trim().isEmpty ? <String, dynamic>{} : json.decode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ?? data['message'] ?? 'Couldn’t move this appointment');
    }
    await loadAppointments();
  }

  Future<void> cancelAppointment(String appointmentId, {String reason = 'Cancelled by patient'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await SecureStorageService.instance.readToken();

      final response = await http.post(
        Uri.parse('${AppConstants.appointmentsUrl}/$appointmentId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'reason': reason,
        })
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Update locally
        final index = _appointments.indexWhere((apt) => apt.id == appointmentId);
        if (index != -1) {
          final apt = _appointments[index];
          _appointments[index] = apt.copyWith(status: 'cancelled');
        }
      } else {
         throw Exception(responseData['error'] ?? responseData['message'] ?? 'Couldn’t cancel this appointment');
      }

    } catch (e) {
       _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch available time slots from the calendar API
  Future<List<Map<String, dynamic>>> fetchAvailableSlots({
    required String professionalId,
    required String professionalType,
    required String date,
    String type = 'clinic',
  }) async {
    try {
      final token = await SecureStorageService.instance.readToken();

      final uri = Uri.parse('${AppConstants.baseUrl}/calendar/available-slots').replace(
        queryParameters: {
          'professionalId': professionalId,
          'professionalType': professionalType,
          'date': date,
          'type': type,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final List<dynamic> slots = responseData['availableSlots'] ?? [];
        return slots.map((s) => Map<String, dynamic>.from(s)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching available slots: $e');
      return [];
    }
  }

  @visibleForTesting
  void debugSeed(List<Appointment> appointments) {
    _appointments = appointments;
    _isLoading = false;
    notifyListeners();
  }

  // An appointment stays "upcoming" until its slot has ended, so a video
  // call that has just started still shows its Join button.
  bool _ended(Appointment a) =>
      a.dateTime.add(Duration(minutes: a.duration)).isBefore(DateTime.now());

  static const _stopped = ['cancelled', 'rejected'];

  List<Appointment> getUpcomingAppointments() {
    return _appointments.where((a) => !a.isTerminal && !_ended(a)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<Appointment> getPastAppointments() {
    return _appointments
        .where((a) => !_stopped.contains(a.status.toLowerCase()))
        .where((a) => a.isTerminal || _ended(a))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  List<Appointment> getCancelledAppointments() {
    return _appointments
        .where((a) => _stopped.contains(a.status.toLowerCase()))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }
}

class BookingResult {
  final String appointmentId;
  final double amount;
  final bool paymentRequired;
  const BookingResult({
    required this.appointmentId,
    required this.amount,
    required this.paymentRequired,
  });
}
