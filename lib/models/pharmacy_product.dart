class PharmacyProduct {
  final String id;
  final String name;
  final String category;
  final String brand;
  final double price;
  final double discount;
  final double rating;
  final int reviews;
  final int stock;
  final String packSize;
  final bool prescriptionRequired;
  final bool isNew;
  final String imageUrl;

  PharmacyProduct({
    required this.id,
    required this.name,
    required this.category,
    this.brand = '',
    required this.price,
    this.discount = 0,
    this.rating = 0,
    this.reviews = 0,
    this.stock = 0,
    this.packSize = '1 Strip',
    this.prescriptionRequired = false,
    this.isNew = false,
    this.imageUrl = '',
  });

  double get discountedPrice =>
      discount > 0 ? price - (price * discount / 100) : price;

  double get savings => price - discountedPrice;

  factory PharmacyProduct.fromJson(Map<String, dynamic> json) {
    return PharmacyProduct(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      brand: json['brand'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      rating: (json['rating'] ?? 0).toDouble(),
      reviews: json['reviews'] ?? 0,
      stock: json['stock'] ?? 0,
      packSize: json['packSize'] ?? '1 Strip',
      prescriptionRequired: json['prescriptionRequired'] ?? false,
      isNew: json['isNew'] ?? false,
      imageUrl: json['imageUrl'] ?? json['image'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'brand': brand,
      'price': price,
      'discount': discount,
      'rating': rating,
      'reviews': reviews,
      'stock': stock,
      'packSize': packSize,
      'prescriptionRequired': prescriptionRequired,
      'isNew': isNew,
      'imageUrl': imageUrl,
    };
  }
}

class CartItem {
  final PharmacyProduct product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get totalPrice => product.discountedPrice * quantity;
}
