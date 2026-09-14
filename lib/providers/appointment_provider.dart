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

      final response = await http.get(
        Uri.parse(AppConstants.appointmentsUrl),
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
          String hospital = 'Aadya Clinic';
          
          if (doc['doctorId'] != null && doc['doctorId'] is Map && professionalType == 'doctor') {
            docId = doc['doctorId']['_id']?.toString() ?? '';
            doctorName = doc['doctorId']['name']?.toString() ?? 'Unknown Doctor';
            docSpecialty = (doc['doctorId']['specialization'] != null && (doc['doctorId']['specialization'] as List).isNotEmpty) 
                ? doc['doctorId']['specialization'][0].toString() 
                : 'General';
            // Extract clinic city if available
            if (doc['doctorId']['clinicAddress'] != null) {
              hospital = doc['doctorId']['clinicAddress']['city']?.toString() ?? 'Aadya Clinic';
            }
          } else if (doc['physioId'] != null && doc['physioId'] is Map && professionalType == 'physio') {
            docId = doc['physioId']['_id']?.toString() ?? '';
            doctorName = doc['physioId']['name']?.toString() ?? 'Unknown Physio';
            docSpecialty = 'Physiotherapy';
            if (doc['physioId']['clinicAddress'] != null) {
              hospital = doc['physioId']['clinicAddress']['city']?.toString() ?? 'Aadya Clinic';
            }
          }

          DateTime parsedDate = DateTime.now();
          String? rawStartTime;
          if (doc['appointmentDate'] != null) {
            try {
              parsedDate = DateTime.parse(doc['appointmentDate'].toString());
              rawStartTime = doc['startTime']?.toString();
              if (rawStartTime != null) {
                final parts = rawStartTime.split(':');
                if (parts.length >= 2) {
                  parsedDate = parsedDate.add(Duration(
                    hours: int.parse(parts[0]),
                    minutes: int.parse(parts[1])
                  ));
                }
              }
            } catch (e) {
              // fallback to now
            }
          }

          return Appointment(
            id: doc['_id']?.toString() ?? '',
            doctorId: docId,
            doctorName: doctorName,
            specialty: docSpecialty,
            hospital: hospital,
            patientName: (doc['patientId'] is Map) ? doc['patientId']['name']?.toString() ?? 'Me' : 'Me',
            dateTime: parsedDate,
            status: doc['status']?.toString() ?? 'pending',
            consultationFee: doc['totalAmount']?.toDouble() ?? doc['consultationFee']?.toDouble() ?? 0.0,
            appointmentType: doc['type']?.toString() ?? 'clinic',
            symptoms: doc['symptoms'] != null && (doc['symptoms'] as List).isNotEmpty ? doc['symptoms'][0].toString() : null,
            createdAt: doc['createdAt'] != null ? DateTime.parse(doc['createdAt'].toString()) : DateTime.now(),
            meetingLink: doc['meetingLink']?.toString(),
            startTime: rawStartTime,
            reason: doc['reason']?.toString(),
            prescriptionId: doc['prescriptionId']?.toString(),
            professionalType: professionalType,
            duration: doc['duration'] ?? 30,
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
    }

    _isLoading = false;
    notifyListeners();
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
          _appointments[index] = Appointment(
            id: apt.id,
            doctorId: apt.doctorId,
            doctorName: apt.doctorName,
            specialty: apt.specialty,
            hospital: apt.hospital,
            patientName: apt.patientName,
            dateTime: apt.dateTime,
            status: 'cancelled',
            consultationFee: apt.consultationFee,
            appointmentType: apt.appointmentType,
            symptoms: apt.symptoms,
            createdAt: apt.createdAt,
            meetingLink: apt.meetingLink,
            startTime: apt.startTime,
            reason: apt.reason,
            prescriptionId: apt.prescriptionId,
            professionalType: apt.professionalType,
            duration: apt.duration,
          );
        }
      } else {
         throw Exception(responseData['error'] ?? 'Failed to cancel appointment');
      }

    } catch (e) {
       _error = 'Cancellation error: $e';
       rethrow;
    }

    _isLoading = false;
    notifyListeners();
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

  List<Appointment> getUpcomingAppointments() {
    return _appointments
        .where((apt) => 
            apt.dateTime.isAfter(DateTime.now()) && 
            !['cancelled', 'completed'].contains(apt.status.toLowerCase()))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<Appointment> getPastAppointments() {
    return _appointments
        .where((apt) => 
            apt.dateTime.isBefore(DateTime.now()) || 
            apt.status.toLowerCase() == 'completed')
        .where((apt) => apt.status.toLowerCase() != 'cancelled')
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  List<Appointment> getCancelledAppointments() {
    return _appointments
        .where((apt) => apt.status.toLowerCase() == 'cancelled')
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }
}