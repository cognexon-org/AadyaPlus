import 'package:flutter/material.dart';
import 'package:aadya_plus/utils/constants.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _filter = 'all';

  final List<Map<String, dynamic>> _payments = [
    {
      'id': '1',
      'type': 'appointment',
      'title': 'Consultation - Dr. Sharma',
      'amount': 500,
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'status': 'completed',
      'method': 'UPI',
    },
    {
      'id': '2',
      'type': 'pharmacy',
      'title': 'Pharmacy Order #ORD1234',
      'amount': 389,
      'date': DateTime.now().subtract(const Duration(days: 3)),
      'status': 'completed',
      'method': 'Card',
    },
    {
      'id': '3',
      'type': 'lab',
      'title': 'Lab Test - CBC',
      'amount': 450,
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'status': 'completed',
      'method': 'UPI',
    },
    {
      'id': '4',
      'type': 'appointment',
      'title': 'Consultation - Dr. Patel',
      'amount': 800,
      'date': DateTime.now().subtract(const Duration(days: 8)),
      'status': 'refunded',
      'method': 'Card',
    },
    {
      'id': '5',
      'type': 'pharmacy',
      'title': 'Pharmacy Order #ORD1199',
      'amount': 1250,
      'date': DateTime.now().subtract(const Duration(days: 12)),
      'status': 'completed',
      'method': 'Net Banking',
    },
  ];

  List<Map<String, dynamic>> get _filteredPayments {
    if (_filter == 'all') return _payments;
    return _payments.where((p) => p['type'] == _filter).toList();
  }

  double get _totalSpent => _payments
      .where((p) => p['status'] == 'completed')
      .fold(0.0, (sum, p) => sum + (p['amount'] as int));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        title: const Text(
          'Payments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Spent',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_totalSpent.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_payments.length} transactions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Filter tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    {'key': 'all', 'label': 'All', 'icon': Icons.list},
                    {'key': 'appointment', 'label': 'Appointments', 'icon': Icons.calendar_today},
                    {'key': 'pharmacy', 'label': 'Pharmacy', 'icon': Icons.local_pharmacy},
                    {'key': 'lab', 'label': 'Lab Tests', 'icon': Icons.science},
                  ].map((tab) {
                    final isSelected = _filter == tab['key'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _filter = tab['key'] as String),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppConstants.primaryColor
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tab['icon'] as IconData,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tab['label'] as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Payments list
              const Text(
                'Transaction History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._filteredPayments.map((payment) => _buildPaymentCard(payment)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    IconData icon;
    Color color;
    switch (payment['type']) {
      case 'appointment':
        icon = Icons.person;
        color = Colors.blue;
        break;
      case 'pharmacy':
        icon = Icons.local_pharmacy;
        color = Colors.orange;
        break;
      case 'lab':
        icon = Icons.science;
        color = Colors.teal;
        break;
      default:
        icon = Icons.payment;
        color = Colors.grey;
    }

    final isRefunded = payment['status'] == 'refunded';
    final date = payment['date'] as DateTime;
    final dateStr = '${date.day}/${date.month}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['title'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        payment['method'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isRefunded ? '+' : '-'}₹${payment['amount']}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isRefunded ? Colors.green : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              if (isRefunded)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Refunded',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
