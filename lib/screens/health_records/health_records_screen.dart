import 'package:aadya_plus/services/patient_records_service.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HealthRecordsScreen extends StatefulWidget {
  const HealthRecordsScreen({super.key});

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  PatientRecordsBundle? _bundle;
  bool _loading = true;
  String? _error;

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
      final bundle = await PatientRecordsService.instance.load();
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
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

  Future<void> _addRecord() async {
    String type = 'medicalHistory';
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Medical Record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Record type'),
                  items: const [
                    DropdownMenuItem(value: 'medicalHistory', child: Text('Medical history')),
                    DropdownMenuItem(value: 'allergy', child: Text('Allergy')),
                    DropdownMenuItem(value: 'medication', child: Text('Current medication')),
                    DropdownMenuItem(value: 'condition', child: Text('Chronic condition')),
                  ],
                  onChanged: (value) => setDialogState(() => type = value ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: _primaryFieldLabel(type)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final value = titleController.text.trim();
                if (value.isEmpty) return;
                final data = <String, dynamic>{'notes': notesController.text.trim()};
                if (type == 'medicalHistory') data['condition'] = value;
                if (type == 'allergy') data['allergen'] = value;
                if (type == 'medication') data['medicineName'] = value;
                if (type == 'condition') data['condition'] = value;
                try {
                  await PatientRecordsService.instance.addMedicalRecord(recordType: type, data: data);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    notesController.dispose();
    if (saved == true) await _load();
  }

  String _primaryFieldLabel(String type) {
    switch (type) {
      case 'allergy':
        return 'Allergen';
      case 'medication':
        return 'Medicine name';
      case 'condition':
        return 'Condition';
      default:
        return 'Condition / history item';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          surfaceTintColor: AppConstants.primaryColor,
          title: const Text('Health Records', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(onPressed: _addRecord, icon: const Icon(Icons.add)),
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Medical'),
              Tab(text: 'Lab Reports'),
              Tab(text: 'Invoices'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorState()
                : TabBarView(
                    children: [
                      _medicalTab(),
                      _labTab(),
                      _invoiceTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _medicalTab() {
    final history = _bundle?.medicalHistory ?? const {};
    final sections = <Map<String, dynamic>>[
      {'title': 'Medical History', 'key': 'medicalHistory', 'field': 'condition', 'icon': Icons.history},
      {'title': 'Allergies', 'key': 'allergies', 'field': 'allergen', 'icon': Icons.warning_amber_outlined},
      {'title': 'Current Medications', 'key': 'currentMedications', 'field': 'medicineName', 'icon': Icons.medication_outlined},
      {'title': 'Chronic Conditions', 'key': 'chronicConditions', 'field': 'condition', 'icon': Icons.favorite_outline},
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: sections.map((section) {
          final rows = _mapList(history[section['key']]);
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: _boxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(section['icon'] as IconData, color: AppConstants.primaryColor),
                    const SizedBox(width: 8),
                    Text(section['title'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  Text('No records', style: TextStyle(color: Colors.grey.shade500))
                else
                  ...rows.map((row) {
                    final title = (row[section['field']] ?? 'Record').toString();
                    final notes = (row['notes'] ?? row['reaction'] ?? row['purpose'] ?? '').toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: notes.isEmpty ? null : Text(notes),
                    );
                  }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _labTab() {
    final reports = _bundle?.labReports ?? const [];
    return RefreshIndicator(
      onRefresh: _load,
      child: reports.isEmpty
          ? _emptyScrollable('No diagnostic reports yet.')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final lab = report['pathologyId'] is Map ? Map<String, dynamic>.from(report['pathologyId']) : const <String, dynamic>{};
                final date = _parseDate(report['scheduledDate'] ?? report['createdAt']);
                final status = (report['status'] ?? 'unknown').toString();
                final title = (report['testName'] ?? report['orderNumber'] ?? 'Diagnostic order').toString();
                final hasReport = report['reportGeneratedAt'] != null || report['reportFile'] != null || status == 'completed';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.science_outlined)),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if ((lab['labName'] ?? '').toString().isNotEmpty) lab['labName'].toString(),
                      if (date != null) DateFormat('dd MMM yyyy').format(date),
                      status.replaceAll('_', ' '),
                    ].join(' • ')),
                    trailing: hasReport
                        ? IconButton(
                            tooltip: 'Open report',
                            icon: const Icon(Icons.download_outlined, color: AppConstants.primaryColor),
                            onPressed: () async {
                              try {
                                await PatientRecordsService.instance.downloadAndOpenLabReport((report['_id'] ?? '').toString());
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }

  Widget _invoiceTab() {
    final invoices = _bundle?.invoices ?? const [];
    return RefreshIndicator(
      onRefresh: _load,
      child: invoices.isEmpty
          ? _emptyScrollable('No invoices yet.')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                final date = _parseDate(invoice['invoiceDate'] ?? invoice['createdAt']);
                final amount = _asDouble(invoice['totalAmount']);
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
                    title: Text((invoice['invoiceNumber'] ?? 'Invoice').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      (invoice['invoiceType'] ?? 'healthcare').toString(),
                      if (date != null) DateFormat('dd MMM yyyy').format(date),
                      (invoice['status'] ?? '').toString(),
                    ].where((e) => e.isNotEmpty).join(' • ')),
                    trailing: Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                );
              },
            ),
    );
  }

  Widget _emptyScrollable(String message) => ListView(
        children: [
          const SizedBox(height: 160),
          Center(child: Text(message, style: TextStyle(color: Colors.grey.shade600))),
        ],
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 42),
              const SizedBox(height: 10),
              Text(_error ?? 'Unable to load records', textAlign: TextAlign.center),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );

  BoxDecoration _boxDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      );

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
