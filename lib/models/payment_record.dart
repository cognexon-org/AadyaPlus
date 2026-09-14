class PaymentRecord {
  final String type;
  final DateTime date;
  final double amount;
  final String reference;
  final Map<String, dynamic> details;

  const PaymentRecord({
    required this.type,
    required this.date,
    required this.amount,
    required this.reference,
    this.details = const {},
  });

  String get title {
    switch (type) {
      case 'appointment':
        return 'Consultation payment';
      case 'labtest':
        return 'Diagnostic payment';
      case 'pharmacy_order':
        return 'Pharmacy order payment';
      default:
        return 'Payment';
    }
  }

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      type: (json['type'] ?? 'payment').toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString())?.toLocal() ?? DateTime.now(),
      amount: _asDouble(json['amount']),
      reference: (json['reference'] ?? '').toString(),
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'])
          : const {},
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class PaymentOrderData {
  final String orderId;
  final int amountPaise;
  final String currency;
  final double payableAmount;
  final String entityType;
  final String entityId;

  const PaymentOrderData({
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.payableAmount,
    required this.entityType,
    required this.entityId,
  });
}
