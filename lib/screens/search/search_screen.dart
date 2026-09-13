import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aadya_plus/providers/doctor_provider.dart';
import 'package:aadya_plus/screens/doctors/doctor_detail_screen.dart';
import 'package:aadya_plus/widgets/doctor_card.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:geolocator/geolocator.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  bool _locationLoading = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Try to get location on init
    _requestLocation();
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

  Future<void> _requestLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationLoading = false;
          _locationError = 'Location services are disabled';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationLoading = false;
            _locationError = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationLoading = false;
          _locationError = 'Location permission permanently denied. Enable in settings.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        final provider = Provider.of<DoctorProvider>(context, listen: false);
        provider.setUserLocation(position.latitude, position.longitude);
        // Auto-sort by nearby when location is obtained
        provider.setSortBy('nearby');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Failed to get location';
        });
      }
    }

    if (mounted) {
      setState(() => _locationLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Find Specialists',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search doctors, specialties, city...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
                autofocus: true,
              ),
            ),
          ),

          // Location status bar
          _buildLocationBar(),

          // Sort + Specialty pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Consumer<DoctorProvider>(
              builder: (context, provider, _) {
                return Column(
                  children: [
                    // Sort options
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildSortChip('Rating', 'rating', Icons.star_rounded, provider),
                          if (provider.hasLocation)
                            _buildSortChip('Nearest', 'nearby', Icons.near_me, provider),
                          _buildSortChip('Fee ↑', 'fee_low', Icons.arrow_upward, provider),
                          _buildSortChip('Fee ↓', 'fee_high', Icons.arrow_downward, provider),
                          _buildSortChip('Experience', 'experience', Icons.work, provider),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Specialty filters
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: provider.getSpecialties().map((specialty) {
                          final isSelected = _selectedFilter == specialty;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              backgroundColor: Colors.white,
                              label: Text(
                                specialty,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppConstants.primaryColor : Colors.grey.shade700,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() => _selectedFilter = specialty);
                                provider.filterDoctors(specialty);
                              },
                              selectedColor: AppConstants.primaryColor.withOpacity(0.15),
                              checkmarkColor: AppConstants.primaryColor,
                              side: BorderSide(
                                color: isSelected ? AppConstants.primaryColor : Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: Consumer<DoctorProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.doctors.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No specialists found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search term or filter',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBar() {
    if (_locationLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade600),
              ),
              const SizedBox(width: 10),
              Text('Getting your location...', style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
            ],
          ),
        ),
      );
    }

    final provider = Provider.of<DoctorProvider>(context, listen: false);
    
    if (provider.hasLocation) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.my_location, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Showing nearest specialists based on your location',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                ),
              ),
              GestureDetector(
                onTap: _requestLocation,
                child: Icon(Icons.refresh, size: 18, color: Colors.green.shade700),
              ),
            ],
          ),
        ),
      );
    }

    if (_locationError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.location_off, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _locationError!,
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ),
              GestureDetector(
                onTap: _requestLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSortChip(String label, String value, IconData icon, DoctorProvider provider) {
    final isSelected = provider.sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => provider.setSortBy(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppConstants.primaryColor : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
