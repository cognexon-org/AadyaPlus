import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aadya_plus/providers/appointment_provider.dart';
import 'package:aadya_plus/widgets/appointment_card.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:aadya_plus/models/appointment.dart';
import 'package:aadya_plus/screens/appointments/reschedule_appointment_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  String _currentFilter = 'upcoming';
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    // Refresh appointments on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppointmentProvider>(context, listen: false).loadAppointments();
    });
  }

  Color _getStatusColor(String status) {
    return AppConstants.getStatusColor(status);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Appointment> _getFilteredAppointments(AppointmentProvider provider) {
    List<Appointment> filtered;
    switch (_currentFilter) {
      case 'upcoming':
        filtered = provider.getUpcomingAppointments();
        break;
      case 'past':
        filtered = provider.getPastAppointments();
        break;
      case 'cancelled':
        filtered = provider.getCancelledAppointments();
        break;
      default: // 'all'
        filtered = provider.appointments;
        break;
    }

    if (_searchTerm.isNotEmpty) {
      filtered = filtered.where((apt) {
        return apt.doctorName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
            apt.specialty.toLowerCase().contains(_searchTerm.toLowerCase()) ||
            (apt.reason ?? '').toLowerCase().contains(_searchTerm.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  void _showCancelDialog(BuildContext context, Appointment appointment) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Appointment', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getStatusColor(appointment.status).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: _getStatusColor(appointment.status)),
                  const SizedBox(width: 4),
                  Text(
                    appointment.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getStatusColor(appointment.status),
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
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Please provide a reason...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final provider = Provider.of<AppointmentProvider>(context, listen: false);
                await provider.cancelAppointment(appointment.id, reason: reason);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Appointment cancelled'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Appointments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('Manage and track your health visits', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: Consumer<AppointmentProvider>(
        builder: (context, provider, child) {
          final filteredAppointments = _getFilteredAppointments(provider);
          
          return Column(
            children: [
              // Search + Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Search bar
                    SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchTerm = val),
                        cursorColor: AppConstants.primaryColor,
                        decoration: InputDecoration(
                          hintText: 'Search by doctor, specialty...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: AppConstants.primaryColor, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppConstants.primaryColor.withOpacity(0.2), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppConstants.primaryColor, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['upcoming', 'past', 'all', 'cancelled'].map((tab) {
                          final isActive = _currentFilter == tab;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _currentFilter = tab),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isActive ? AppConstants.primaryColor : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  tab[0].toUpperCase() + tab.substring(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isActive ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Appointments List
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredAppointments.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: () => provider.loadAppointments(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredAppointments.length,
                              itemBuilder: (context, index) {
                                final appointment = filteredAppointments[index];
                                return AppointmentCard(
                                  appointment: appointment,
                                  onCancel: () => _showCancelDialog(context, appointment),
                                  onReschedule: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RescheduleAppointmentScreen(
                                          appointment: appointment,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchTerm.isNotEmpty
                ? 'No appointments match "$_searchTerm"'
                : 'No $_currentFilter appointments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'Book an appointment with a doctor to get started',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}