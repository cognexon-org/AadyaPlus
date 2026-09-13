class User {
  final String id;
  final String? profileId;
  final String name;
  final String email;
  final String phone;
  final String? profileImage;
  final DateTime createdAt;

  User({
    required this.id,
    this.profileId,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImage,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      profileId: json['profileId'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      profileImage: json['profileImage'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}