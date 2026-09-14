import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:aadya_plus/services/secure_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyPharmacyScreen extends StatefulWidget {
  const NearbyPharmacyScreen({super.key});

  @override
  State<NearbyPharmacyScreen> createState() => _NearbyPharmacyScreenState();
}

class _NearbyPharmacyScreenState extends State<NearbyPharmacyScreen> {
  List<Map<String, dynamic>> _pharmacies = [];
  List<Map<String, dynamic>> _filteredPharmacies = [];
  bool _loading = true;
  bool _locationLoading = true;
  String? _locationError;
  double? _userLat;
  double? _userLng;
  int _radius = 25;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationLoading = false;
          _locationError = 'Location services are disabled. Please enable GPS.';
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
          _locationError = 'Location permanently denied. Enable in Settings.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
        _locationLoading = false;
      });

      _fetchPharmacies();
    } catch (e) {
      setState(() {
        _locationLoading = false;
        _locationError = 'Failed to get location: $e';
      });
    }
  }

  Future<void> _fetchPharmacies() async {
    if (_userLat == null || _userLng == null) return;

    setState(() => _loading = true);

    try {
      final token = await SecureStorageService.instance.readToken();

      final uri = Uri.parse('${AppConstants.pharmacyUrl}/all').replace(
        queryParameters: {
          'lat': _userLat.toString(),
          'lng': _userLng.toString(),
          'radius': _radius.toString(),
          'limit': '50',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final List<dynamic> pharmacyList = data['pharmacies'] ?? [];
        setState(() {
          _pharmacies = pharmacyList.map((p) => Map<String, dynamic>.from(p)).toList();
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Error fetching pharmacies: $e');
    }

    setState(() => _loading = false);
  }

  void _applyFilters() {
    var filtered = List<Map<String, dynamic>>.from(_pharmacies);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        final name = (p['pharmacyName'] ?? '').toString().toLowerCase();
        final city = (p['address']?['city'] ?? '').toString().toLowerCase();
        final street = (p['address']?['street'] ?? '').toString().toLowerCase();
        return name.contains(q) || city.contains(q) || street.contains(q);
      }).toList();
    }

    setState(() => _filteredPharmacies = filtered);
  }

  String _formatDistance(dynamic distance) {
    if (distance == null) return '';
    final d = double.tryParse(distance.toString()) ?? 0;
    return '${d.toStringAsFixed(1)} km';
  }

  bool _isOpenNow(Map<String, dynamic>? operatingHours) {
    if (operatingHours == null) return false;
    final now = DateTime.now();
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayName = days[now.weekday - 1];
    final hours = operatingHours[dayName];
    if (hours == null || hours['closed'] == true) return false;
    
    final openStr = hours['open']?.toString() ?? '09:00';
    final closeStr = hours['close']?.toString() ?? '21:00';
    
    final openParts = openStr.split(':');
    final closeParts = closeStr.split(':');
    
    if (openParts.length < 2 || closeParts.length < 2) return false;
    
    final openMinutes = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
    final closeMinutes = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
    final currentMinutes = now.hour * 60 + now.minute;
    
    return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
  }

  Future<void> _callPharmacy(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showDetailModal(Map<String, dynamic> pharmacy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PharmacyDetailSheet(
        pharmacy: pharmacy,
        isOpenNow: _isOpenNow(pharmacy['operatingHours']),
        onCall: () {
          final phone = pharmacy['phone']?.toString();
          if (phone != null && phone.isNotEmpty) _callPharmacy(phone);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Location loading state
    if (_locationLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppConstants.primaryColor,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Nearby Pharmacies', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Getting your location...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Location error state
    if (_locationError != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppConstants.primaryColor,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Nearby Pharmacies', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(Icons.location_off, size: 40, color: Colors.red.shade400),
                ),
                const SizedBox(height: 20),
                const Text('Location Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _locationError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _getUserLocation,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Retry', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pharmacies Near You', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(
              'Found ${_filteredPharmacies.length} pharmacies within $_radius km',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          // Radius selector
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune, color: Colors.white),
            onSelected: (val) {
              setState(() => _radius = val);
              _fetchPharmacies();
            },
            itemBuilder: (ctx) => [5, 10, 15, 25, 50].map((r) {
              return PopupMenuItem<int>(
                value: r,
                child: Row(
                  children: [
                    if (_radius == r) Icon(Icons.check, size: 18, color: AppConstants.primaryColor),
                    if (_radius == r) const SizedBox(width: 8),
                    Text('Within $r km'),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  _searchQuery = val;
                  _applyFilters();
                },
                cursorColor: AppConstants.primaryColor,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search pharmacies by name or location...',
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

          // Location status bar
          Padding(
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
                      'Showing pharmacies near your location',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _getUserLocation();
                    },
                    child: Icon(Icons.refresh, size: 18, color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Pharmacy list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPharmacies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_pharmacy_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No pharmacies match "$_searchQuery"'
                                  : 'No pharmacies found within $_radius km',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try increasing the radius',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchPharmacies,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredPharmacies.length,
                          itemBuilder: (context, index) {
                            return _buildPharmacyCard(_filteredPharmacies[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacyCard(Map<String, dynamic> pharmacy) {
    final name = pharmacy['pharmacyName']?.toString() ?? 'Unknown Pharmacy';
    final street = pharmacy['address']?['street']?.toString() ?? '';
    final city = pharmacy['address']?['city']?.toString() ?? '';
    final distance = pharmacy['distance'];
    final rating = (pharmacy['averageRating'] ?? 0).toDouble();
    final reviews = pharmacy['totalReviews'] ?? 0;
    final deliveryAvailable = pharmacy['deliveryAvailable'] == true;
    final deliveryCharge = pharmacy['deliveryCharge'] ?? 0;
    final minOrder = pharmacy['minimumOrderAmount'] ?? 0;
    final phone = pharmacy['phone']?.toString();
    final isOpen = _isOpenNow(pharmacy['operatingHours']);

    // Get hours for today
    final now = DateTime.now();
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final dayName = days[now.weekday - 1];
    final todayHours = pharmacy['operatingHours']?[dayName];
    final openTime = todayHours?['open']?.toString() ?? '9:00';
    final closeTime = todayHours?['close']?.toString() ?? '21:00';

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _showDetailModal(pharmacy),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store icon
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.local_pharmacy, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                '$street, $city',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Distance badge
                            if (distance != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.near_me, size: 11, color: Colors.blue.shade600),
                                    const SizedBox(width: 3),
                                    Text(
                                      _formatDistance(distance),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 8),
                            // Open/Closed
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOpen ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isOpen ? Icons.check_circle : Icons.cancel,
                                    size: 11,
                                    color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isOpen ? 'Open' : 'Closed',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isOpen ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Rating
                  if (rating > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Info bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Delivery info
                    Icon(
                      deliveryAvailable ? Icons.local_shipping : Icons.store,
                      size: 16,
                      color: deliveryAvailable ? Colors.blue.shade600 : Colors.orange.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deliveryAvailable ? 'Delivery Available' : 'Store Pickup Only',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                          if (deliveryAvailable)
                            Text(
                              'Min. ₹$minOrder • ₹$deliveryCharge delivery',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 24, color: Colors.grey.shade300),
                    const SizedBox(width: 12),
                    // Hours
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '$openTime - $closeTime',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDetailModal(pharmacy),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('View Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (phone != null && phone.isNotEmpty) {
                          _callPharmacy(phone);
                        }
                      },
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Call', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for pharmacy details (matching web modal)
class _PharmacyDetailSheet extends StatefulWidget {
  final Map<String, dynamic> pharmacy;
  final bool isOpenNow;
  final VoidCallback onCall;

  const _PharmacyDetailSheet({
    required this.pharmacy,
    required this.isOpenNow,
    required this.onCall,
  });

  @override
  State<_PharmacyDetailSheet> createState() => _PharmacyDetailSheetState();
}

class _PharmacyDetailSheetState extends State<_PharmacyDetailSheet> {
  String _activeTab = 'info';

  @override
  Widget build(BuildContext context) {
    final p = widget.pharmacy;
    final name = p['pharmacyName']?.toString() ?? 'Pharmacy';
    final rating = (p['averageRating'] ?? 0).toDouble();
    final reviews = p['totalReviews'] ?? 0;
    final distance = p['distance'];
    final address = p['address'];
    final phone = p['phone']?.toString();
    final email = p['email']?.toString();
    final deliveryAvailable = p['deliveryAvailable'] == true;
    final deliveryCharge = p['deliveryCharge'] ?? 0;
    final minOrder = p['minimumOrderAmount'] ?? 0;
    final deliveryRadius = p['deliveryRadius'];
    final paymentMethods = p['paymentMethods'] != null ? List<String>.from(p['paymentMethods']) : <String>[];
    final operatingHours = p['operatingHours'] as Map<String, dynamic>?;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)]),
                  ),
                  child: const Icon(Icons.local_pharmacy, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          if (rating > 0) ...[
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text('${rating.toStringAsFixed(1)} ($reviews reviews)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.isOpenNow ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.isOpenNow ? 'Open Now' : 'Closed',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isOpenNow ? Colors.green.shade700 : Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: ['info', 'hours', 'services'].map((tab) {
                final isActive = _activeTab == tab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = tab),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isActive ? AppConstants.primaryColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        tab == 'info' ? 'Information' : tab == 'hours' ? 'Hours' : 'Services',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? AppConstants.primaryColor : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),

          // Tab content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _activeTab == 'info'
                  ? _buildInfoTab(address, distance, phone, email, deliveryAvailable, deliveryCharge, minOrder, deliveryRadius, paymentMethods)
                  : _activeTab == 'hours'
                      ? _buildHoursTab(operatingHours)
                      : _buildServicesTab(deliveryAvailable, deliveryCharge),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onCall();
                    },
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(Map<String, dynamic>? address, dynamic distance, String? phone, String? email, bool delivery, dynamic charge, dynamic minOrder, dynamic radius, List<String> payments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.location_on, 'Address'),
        Text('${address?['street'] ?? ''}\n${address?['city'] ?? ''}, ${address?['state'] ?? ''} - ${address?['pincode'] ?? ''}',
            style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
        if (distance != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${double.tryParse(distance.toString())?.toStringAsFixed(1)} km from your location',
                style: TextStyle(fontSize: 13, color: Colors.blue.shade600, fontWeight: FontWeight.w500)),
          ),
        const SizedBox(height: 20),
        _sectionTitle(Icons.phone, 'Contact'),
        if (phone != null && phone.isNotEmpty)
          _contactRow(Icons.phone, phone),
        if (email != null && email.isNotEmpty)
          _contactRow(Icons.email, email),
        const SizedBox(height: 20),
        _sectionTitle(Icons.local_shipping, 'Delivery'),
        delivery
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green.shade600), const SizedBox(width: 6), const Text('Delivery Available', style: TextStyle(color: Colors.green))]),
                  if ((minOrder as num) > 0) Text('Min. Order: ₹$minOrder', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  if ((charge as num) > 0) Text('Delivery Charge: ₹$charge', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  if (radius != null) Text('Delivery Radius: $radius km', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              )
            : Row(children: [Icon(Icons.info, size: 16, color: Colors.orange.shade600), const SizedBox(width: 6), const Text('Store Pickup Only', style: TextStyle(color: Colors.orange))]),
        if (payments.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle(Icons.payment, 'Payment Methods'),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: payments.map((m) => Chip(label: Text(m, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.grey.shade100, padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildHoursTab(Map<String, dynamic>? hours) {
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.schedule, 'Operating Hours'),
        const SizedBox(height: 8),
        ...days.map((day) {
          final h = hours?[day];
          final isClosed = h == null || h['closed'] == true;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(day[0].toUpperCase() + day.substring(1), style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  isClosed ? 'Closed' : '${h?['open'] ?? '9:00'} - ${h?['close'] ?? '21:00'}',
                  style: TextStyle(color: isClosed ? Colors.red.shade600 : Colors.grey.shade700),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildServicesTab(bool delivery, dynamic charge) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.medical_services, 'Available Services'),
        const SizedBox(height: 12),
        _serviceCard(Icons.description, 'Prescription Filling', 'Upload and fill prescriptions'),
        if (delivery)
          _serviceCard(Icons.local_shipping, 'Home Delivery', charge != null && (charge as num) > 0 ? '₹$charge delivery' : 'Free delivery'),
        _serviceCard(Icons.medication, 'Medicine Consultation', 'Pharmacist consultation available'),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppConstants.primaryColor),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [Icon(icon, size: 14, color: Colors.grey.shade400), const SizedBox(width: 8), Text(text, style: TextStyle(color: Colors.grey.shade700))]),
    );
  }

  Widget _serviceCard(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppConstants.primaryColor),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ],
      ),
    );
  }
}
