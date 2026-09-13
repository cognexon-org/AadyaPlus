import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aadya_plus/providers/doctor_provider.dart';
import 'package:aadya_plus/widgets/doctor_card.dart';
import 'package:aadya_plus/screens/doctors/doctor_detail_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:geolocator/geolocator.dart';

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  final _searchController = TextEditingController();
  bool _locationLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final provider = Provider.of<DoctorProvider>(context, listen: false);
    provider.searchDoctors(_searchController.text);
  }

  Future<void> _fetchLocation() async {
    final provider = Provider.of<DoctorProvider>(context, listen: false);
    if (provider.hasLocation) return; // Already have it

    setState(() => _locationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationLoading = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationLoading = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        provider.setUserLocation(position.latitude, position.longitude);
      }
    } catch (_) {}
    if (mounted) setState(() => _locationLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Find Specialists',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white, size: 20),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                cursorColor: AppConstants.primaryColor,
                decoration: InputDecoration(
                  hintText: 'Search by doctor or specialty...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: AppConstants.primaryColor, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
          ),

          // Sort bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer<DoctorProvider>(
              builder: (context, provider, _) {
                return SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _sortChip('Rating', 'rating', Icons.star_rounded, provider),
                      if (provider.hasLocation)
                        _sortChip('Nearest', 'nearby', Icons.near_me_rounded, provider),
                      _sortChip('Fee Low', 'fee_low', Icons.arrow_upward_rounded, provider),
                      _sortChip('Experience', 'experience', Icons.work_outline_rounded, provider),
                    ],
                  ),
                );
              },
            ),
          ),

          // Active specialty filter chip
          Consumer<DoctorProvider>(
            builder: (context, provider, child) {
              if (provider.selectedSpecialty != 'All') {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Chip(
                    label: Text('Specialty: ${provider.selectedSpecialty}'),
                    onDeleted: () => provider.filterDoctors('All'),
                    backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
              return const SizedBox();
            },
          ),

          // Location status
          if (_locationLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade400)),
                  const SizedBox(width: 8),
                  Text('Getting your location...', style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Doctor list
          Consumer<DoctorProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Expanded(child: Center(child: CircularProgressIndicator()));
              }

              if (provider.doctors.isEmpty) {
                return const Expanded(child: Center(child: Text('No doctors found')));
              }

              return Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.refreshDoctors(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.doctors.length,
                    itemBuilder: (context, index) {
                      final doctor = provider.doctors[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DoctorCard(
                          doctor: doctor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DoctorDetailScreen(doctorId: doctor.id),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String value, IconData icon, DoctorProvider provider) {
    final isSelected = provider.sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => provider.setSortBy(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppConstants.primaryColor : Colors.grey.shade200),
            boxShadow: isSelected ? [
              BoxShadow(
                color: AppConstants.primaryColor.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: isSelected ? Colors.white : Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                label, 
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.w700, 
                  color: isSelected ? Colors.white : Colors.grey.shade600
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final provider = Provider.of<DoctorProvider>(context, listen: false);
        final specialties = provider.getSpecialties();

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by Specialty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: specialties.map((specialty) {
                  return FilterChip(
                    label: Text(specialty),
                    selected: provider.selectedSpecialty == specialty,
                    onSelected: (selected) {
                      provider.filterDoctors(specialty);
                      Navigator.pop(context);
                    },
                    selectedColor: AppConstants.primaryColor.withOpacity(0.2),
                    checkmarkColor: AppConstants.primaryColor,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    provider.filterDoctors('All');
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Clear Filters'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
