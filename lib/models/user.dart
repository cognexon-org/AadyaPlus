class User {
  final String id;
  final String? profileId;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isVerified;
  final bool profileCompleted;
  final String? profileImage;
  final DateTime createdAt;

  /// Notification channels and language, as saved on the account.
  final Map<String, dynamic> preferences;

  bool notifies(String channel) {
    final n = preferences['notifications'];
    return n is Map ? n[channel] != false : true;
  }

  User({
    required this.id,
    this.profileId,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'patient',
    this.isVerified = false,
    this.profileCompleted = false,
    this.profileImage,
    required this.createdAt,
    this.preferences = const {},
  });

  User copyWith({
    String? id,
    String? profileId,
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isVerified,
    bool? profileCompleted,
    String? profileImage,
    DateTime? createdAt,
    Map<String, dynamic>? preferences,
  }) {
    return User(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      preferences: preferences ?? this.preferences,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt']?.toString();
    return User(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      profileId: json['profileId']?.toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      role: (json['role'] ?? 'patient').toString(),
      isVerified: json['isVerified'] == true,
      profileCompleted:
          json['profileCompleted'] == true || json['profileId'] != null,
      profileImage: json['profileImage']?.toString(),
      createdAt: createdAtRaw != null
          ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
          : DateTime.now(),
      preferences: json['preferences'] is Map
          ? Map<String, dynamic>.from(json['preferences'])
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isVerified': isVerified,
      'profileCompleted': profileCompleted,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
      'preferences': preferences,
    };
  }
}
