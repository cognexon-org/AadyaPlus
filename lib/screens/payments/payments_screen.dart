import 'package:aadya_plus/models/payment_record.dart';
import 'package:aadya_plus/services/payment_service.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentRecord> _payments = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payments = await PaymentService.instance.history();
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<PaymentRecord> get _filtered {
    if (_filter == 'all') return _payments;
    return _payments.where((item) => item.type == _filter).toList();
  }

  double get _totalSpent => _payments.fold(0.0, (sum, item) => sum + item.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        title: const Text('Payments', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)]),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Verified payments', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              '₹${_totalSpent.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('${_payments.length} transactions', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        children: [
                          _filterChip('all', 'All'),
                          _filterChip('appointment', 'Appointments'),
                          _filterChip('labtest', 'Diagnostics'),
                          _filterChip('pharmacy_order', 'Pharmacy'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if (_filtered.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: const Text('No verified payments found.'),
                        )
                      else
                        ..._filtered.map(_paymentCard),
                    ],
                  ),
                ),
    );
  }

  Widget _filterChip(String key, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == key,
      onSelected: (_) => setState(() => _filter = key),
      selectedColor: AppConstants.primaryColor.withOpacity(0.15),
    );
  }

  Widget _paymentCard(PaymentRecord payment) {
    final isAppointment = payment.type == 'appointment';
    final isPharmacy = payment.type == 'pharmacy_order';
    final color = isAppointment
        ? Colors.blue
        : isPharmacy
            ? Colors.orange
            : Colors.teal;
    final icon = isAppointment
        ? Icons.person_outline
        : isPharmacy
            ? Icons.local_pharmacy_outlined
            : Icons.science_outlined;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(DateFormat('dd MMM yyyy, hh:mm a').format(payment.date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (payment.reference.isNotEmpty)
                  Text('Ref: ${payment.reference}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text('₹${payment.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 42),
            const SizedBox(height: 10),
            Text(_error ?? 'Unable to load payments', textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
