class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String hospital;
  final double rating;
  final int reviews;
  final double consultationFee;
  final int experience;
  final String imageUrl;
  final String description;
  final List<String> languages;
  final Map<String, List<String>> availability;
  
  // Fee fields
  final double videoCallFee;
  final double homeVisitFee;
  final List<dynamic> services;
  final String verificationStatus;
  final String gender;
  final int totalConsultations;
  final String professionalType;

  // Location fields for distance calculation
  final double? latitude;
  final double? longitude;
  double? distance; // calculated client-side, not final

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.hospital,
    required this.rating,
    required this.reviews,
    required this.consultationFee,
    required this.experience,
    required this.imageUrl,
    required this.description,
    required this.languages,
    required this.availability,
    
    this.videoCallFee = 0.0,
    this.homeVisitFee = 0.0,
    this.services = const [],
    this.verificationStatus = 'pending',
    this.gender = '',
    this.totalConsultations = 0,
    this.professionalType = 'doctor',
    this.latitude,
    this.longitude,
    this.distance,
  });

  factory Doctor.fromJson(Map<String, dynamic> json, {String defaultType = 'doctor'}) {
    return Doctor(
      id: json['id'],
      name: json['name'],
      specialty: json['specialty'],
      hospital: json['hospital'],
      rating: json['rating'].toDouble(),
      reviews: json['reviews'],
      consultationFee: json['consultationFee'].toDouble(),
      experience: json['experience'],
      imageUrl: json['imageUrl'] ?? '',
      description: json['description'] ?? '',
      languages: json['languages'] != null ? List<String>.from(json['languages']) : [],
      availability: json['availability'] != null ? Map<String, List<String>>.from(json['availability']) : {},
      
      videoCallFee: (json['videoCallFee'] ?? 0).toDouble(),
      homeVisitFee: (json['homeVisitFee'] ?? 0).toDouble(),
      services: json['services'] != null ? List<dynamic>.from(json['services']) : [],
      verificationStatus: json['verificationStatus'] ?? 'pending',
      gender: json['gender'] ?? '',
      totalConsultations: json['totalConsultations'] ?? 0,
      professionalType: json['professionalType'] ?? defaultType,
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      distance: json['distance']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialty': specialty,
      'hospital': hospital,
      'rating': rating,
      'reviews': reviews,
      'consultationFee': consultationFee,
      'experience': experience,
      'imageUrl': imageUrl,
      'description': description,
      'languages': languages,
      'availability': availability,
      
      'videoCallFee': videoCallFee,
      'homeVisitFee': homeVisitFee,
      'services': services,
      'verificationStatus': verificationStatus,
      'gender': gender,
      'totalConsultations': totalConsultations,
      'professionalType': professionalType,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
    };
  }
}