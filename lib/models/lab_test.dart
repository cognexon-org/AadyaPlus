class LabTest {
  final String id;
  final String name;
  final String description;
  final double price;
  final double discountPrice;
  final String preparation;
  final String reportTime;
  final List<String> parameters;
  final bool fastingRequired;

  LabTest({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.discountPrice,
    required this.preparation,
    required this.reportTime,
    required this.parameters,
    required this.fastingRequired,
  });

  factory LabTest.fromJson(Map<String, dynamic> json) {
    return LabTest(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: json['price'].toDouble(),
      discountPrice: json['discountPrice'].toDouble(),
      preparation: json['preparation'],
      reportTime: json['reportTime'],
      parameters: List<String>.from(json['parameters']),
      fastingRequired: json['fastingRequired'],
    );
  }
}