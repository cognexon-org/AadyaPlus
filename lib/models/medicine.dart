class Medicine {
  final String id;
  final String name;
  final String manufacturer;
  final String description;
  final String dosage;
  final double price;
  final double discountPrice;
  final int stock;
  final String imageUrl;
  final bool requiresPrescription;
  final List<String> categories;

  Medicine({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.description,
    required this.dosage,
    required this.price,
    required this.discountPrice,
    required this.stock,
    required this.imageUrl,
    required this.requiresPrescription,
    required this.categories,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'],
      name: json['name'],
      manufacturer: json['manufacturer'],
      description: json['description'],
      dosage: json['dosage'],
      price: json['price'].toDouble(),
      discountPrice: json['discountPrice'].toDouble(),
      stock: json['stock'],
      imageUrl: json['imageUrl'],
      requiresPrescription: json['requiresPrescription'],
      categories: List<String>.from(json['categories']),
    );
  }
}