import 'dart:async';

import 'package:aadya_plus/providers/lab_test_provider.dart';
import 'package:aadya_plus/screens/lab_tests/diagnostic_booking_screen.dart';
import 'package:aadya_plus/screens/pathology/pathology_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LabTestScreen extends StatefulWidget {
  const LabTestScreen({super.key});
  @override
  State<LabTestScreen> createState() => _LabTestScreenState();
}

class _LabTestScreenState extends State<LabTestScreen> {
  final _search = TextEditingController();
  bool _homeOnly = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) context.read<LabTestProvider>().searchCatalog(query: value, homeCollection: _homeOnly);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LabTestProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Diagnostic Tests', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(tooltip: 'My diagnostic orders', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PathologyScreen())), icon: const Icon(Icons.receipt_long_outlined))],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            TextField(
              controller: _search,
              onChanged: _searchChanged,
              decoration: InputDecoration(
                hintText: 'Search CBC, thyroid, diabetes, packages...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true, fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _homeOnly,
              title: const Text('Home collection only', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Show tests available for collection at home'),
              onChanged: (v) { setState(() => _homeOnly = v); p.searchCatalog(query: _search.text, homeCollection: v); },
            ),
          ]),
        ),
        if (p.isLoading) const LinearProgressIndicator(),
        if (p.error != null) Padding(padding: const EdgeInsets.all(10), child: Text(p.error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => p.searchCatalog(query: _search.text, homeCollection: _homeOnly),
            child: p.catalog.isEmpty
                ? ListView(children: const [SizedBox(height: 100), Center(child: Text('No matching diagnostic tests or packages.'))])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                    itemCount: p.catalog.length,
                    itemBuilder: (context, index) {
                      final row = p.catalog[index];
                      final item = row['item'] is Map ? Map<String, dynamic>.from(row['item']) : <String, dynamic>{};
                      final isPackage = row['kind'] == 'package';
                      final name = (isPackage ? item['packageName'] : item['testName'])?.toString() ?? 'Diagnostic item';
                      final price = _double(item['price']);
                      final lab = (row['labName'] ?? 'Lab').toString();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              CircleAvatar(backgroundColor: Colors.purple.shade50, child: Icon(isPackage ? Icons.inventory_2_outlined : Icons.biotech_outlined, color: Colors.purple)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                                Text(lab, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ])),
                              Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppConstants.primaryColor)),
                            ]),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 5, children: [
                              if (isPackage) const Chip(label: Text('Package')),
                              if (!isPackage && item['fastingRequired'] == true) const Chip(label: Text('Fasting')),
                              if (row['homeCollectionAvailable'] == true) const Chip(label: Text('Home collection')),
                              if (!isPackage && item['reportTime'] != null) Chip(label: Text('Report ~${item['reportTime']}h')),
                            ]),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DiagnosticBookingScreen(catalogItem: row))),
                                child: const Text('Select & book'),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }

  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}
