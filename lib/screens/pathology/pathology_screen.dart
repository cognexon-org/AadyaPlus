import 'package:aadya_plus/providers/lab_test_provider.dart';
import 'package:aadya_plus/screens/lab_tests/lab_test_screen.dart';
import 'package:aadya_plus/screens/pathology/diagnostic_order_details_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PathologyScreen extends StatefulWidget {
  const PathologyScreen({super.key});
  @override
  State<PathologyScreen> createState() => _PathologyScreenState();
}

class _PathologyScreenState extends State<PathologyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<LabTestProvider>().loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LabTestProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('My Diagnostics', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LabTestScreen())), icon: const Icon(Icons.add_circle_outline), tooltip: 'Book test')],
      ),
      body: RefreshIndicator(
        onRefresh: p.loadOrders,
        child: p.orders.isEmpty
            ? ListView(children: [
                const SizedBox(height: 100),
                const Icon(Icons.biotech_outlined, size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                const Center(child: Text('No diagnostic bookings yet.')),
                Center(child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LabTestScreen())), child: const Text('Book a test or package'))),
              ])
            : ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: p.orders.length,
                itemBuilder: (context, index) {
                  final o = p.orders[index];
                  final lab = o['pathologyId'] is Map ? Map<String, dynamic>.from(o['pathologyId']) : <String, dynamic>{};
                  final tests = _list(o['tests']);
                  final packages = _list(o['packages']);
                  final title = packages.isNotEmpty ? (packages.first['packageName'] ?? 'Diagnostic package').toString() : tests.isNotEmpty ? (tests.first['testName'] ?? 'Diagnostic test').toString() : 'Diagnostic order';
                  final status = _label(o['status']);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: CircleAvatar(backgroundColor: Colors.purple.shade50, child: const Icon(Icons.science_outlined, color: Colors.purple)),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text('${lab['labName'] ?? 'Lab'}\n$status • ${_label(o['type'])}${o['type'] == 'home_collection' ? ' • ${_label(o['collectionStatus'])}' : ''}'),
                      isThreeLine: true,
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('₹${_double(o['totalAmount']).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppConstants.primaryColor)),
                        const Icon(Icons.chevron_right),
                      ]),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DiagnosticOrderDetailsScreen(orderId: _id(o)))),
                    ),
                  );
                },
              ),
      ),
    );
  }

  static String _id(Map<String, dynamic> m) => (m['_id'] ?? m['id'] ?? '').toString();
  static List<Map<String, dynamic>> _list(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  static String _label(dynamic value) => value.toString().replaceAll('_', ' ').split(' ').map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}').join(' ');
}
