import 'package:flutter/material.dart';
import 'package:aadya_plus/models/health_record.dart';
import 'package:aadya_plus/utils/constants.dart';

class HealthRecordsScreen extends StatelessWidget {
  const HealthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data
    final List<HealthRecord> records = [
      HealthRecord(
        id: '1',
        title: 'Blood Test Report',
        type: 'Lab Report',
        date: DateTime.now().subtract(const Duration(days: 30)),
        doctorName: 'Dr. Sarah Johnson',
        hospitalName: 'Apollo Hospital',
      ),
      HealthRecord(
        id: '2',
        title: 'X-Ray Chest',
        type: 'Scan',
        date: DateTime.now().subtract(const Duration(days: 60)),
        doctorName: 'Dr. Rajesh Kumar',
        hospitalName: 'Fortis Hospital',
      ),
      HealthRecord(
        id: '3',
        title: 'Prescription',
        type: 'Prescription',
        date: DateTime.now().subtract(const Duration(days: 15)),
        doctorName: 'Dr. Priya Sharma',
        hospitalName: 'Manipal Hospital',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Health Records',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddRecordDialog(context),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.medical_information),
              title: Text(record.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type: ${record.type}'),
                  Text('Date: ${_formatDate(record.date)}'),
                  if (record.doctorName != null)
                    Text('Doctor: ${record.doctorName}'),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showRecordDetails(context, record);
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showRecordDetails(BuildContext context, HealthRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${record.type}'),
            Text('Date: ${_formatDate(record.date)}'),
            if (record.doctorName != null)
              Text('Doctor: ${record.doctorName}'),
            if (record.hospitalName != null)
              Text('Hospital: ${record.hospitalName}'),
            if (record.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Description: ${record.description}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              // Share or download record
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _showAddRecordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Health Record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Record Title',
              ),
            ),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Record Type',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Lab Report',
                  child: Text('Lab Report'),
                ),
                DropdownMenuItem(
                  value: 'Prescription',
                  child: Text('Prescription'),
                ),
                DropdownMenuItem(
                  value: 'Scan',
                  child: Text('Scan'),
                ),
                DropdownMenuItem(
                  value: 'Vaccination',
                  child: Text('Vaccination'),
                ),
                DropdownMenuItem(
                  value: 'Other',
                  child: Text('Other'),
                ),
              ],
              onChanged: (value) {},
            ),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Add record functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Record added successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Add Record'),
          ),
        ],
      ),
    );
  }
}