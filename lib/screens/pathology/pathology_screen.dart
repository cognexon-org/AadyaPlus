import 'package:flutter/material.dart';
import 'package:aadya_plus/utils/constants.dart';

class PathologyScreen extends StatefulWidget {
  const PathologyScreen({super.key});

  @override
  State<PathologyScreen> createState() => _PathologyScreenState();
}

class _PathologyScreenState extends State<PathologyScreen> {
  String _filter = 'all';
  final _searchController = TextEditingController();

  final List<Map<String, dynamic>> _reports = [
    {
      'id': '1',
      'testName': 'Complete Blood Count (CBC)',
      'labName': 'Medlife Diagnostics',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'amount': 450,
      'status': 'completed',
      'hasReport': true,
    },
    {
      'id': '2',
      'testName': 'Lipid Profile',
      'labName': 'SRL Diagnostics',
      'date': DateTime.now().subtract(const Duration(days: 7)),
      'amount': 800,
      'status': 'completed',
      'hasReport': true,
    },
    {
      'id': '3',
      'testName': 'Thyroid Function Test',
      'labName': 'PathCare Labs',
      'date': DateTime.now().add(const Duration(days: 3)),
      'amount': 650,
      'status': 'pending',
      'hasReport': false,
    },
    {
      'id': '4',
      'testName': 'HbA1c',
      'labName': 'Medlife Diagnostics',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'amount': 550,
      'status': 'processing',
      'hasReport': false,
    },
    {
      'id': '5',
      'testName': 'Liver Function Test',
      'labName': 'SRL Diagnostics',
      'date': DateTime.now().subtract(const Duration(days: 15)),
      'amount': 700,
      'status': 'completed',
      'hasReport': true,
    },
  ];

  List<Map<String, dynamic>> get _filteredReports {
    var filtered = _reports;
    if (_filter != 'all') {
      filtered = filtered
          .where((r) => r['status'] == _filter)
          .toList();
    }
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      filtered = filtered.where((r) {
        return (r['testName'] as String).toLowerCase().contains(q) ||
            (r['labName'] as String).toLowerCase().contains(q);
      }).toList();
    }
    filtered.sort((a, b) =>
        (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return filtered;
  }

  int get _completedCount =>
      _reports.where((r) => r['status'] == 'completed').length;
  int get _pendingCount =>
      _reports.where((r) => r['status'] == 'pending').length;
  double get _totalSpent =>
      _reports.fold(0.0, (sum, r) => sum + (r['amount'] as int));

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Lab Reports',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search + Book
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        cursorColor: AppConstants.primaryColor,
                        decoration: InputDecoration(
                          hintText: 'Search reports...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: AppConstants.primaryColor, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppConstants.primaryColor.withOpacity(0.2), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppConstants.primaryColor, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Book Test'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stats Row
                Row(
                  children: [
                    _buildStatCard(
                      'Total Tests',
                      '${_reports.length}',
                      Icons.science,
                      AppConstants.primaryColor,
                      filled: true,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'Completed',
                      '$_completedCount',
                      Icons.check_circle,
                      Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'Pending',
                      '$_pendingCount',
                      Icons.schedule,
                      Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'Spent',
                      '₹${_totalSpent.toInt()}',
                      Icons.receipt_long,
                      Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Filter tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'completed', 'pending', 'processing']
                        .map((status) {
                      final isSelected = _filter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _filter = status),
                          selectedColor: AppConstants.primaryColor,
                          backgroundColor: Colors.grey[100],
                          checkmarkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Reports
                if (_filteredReports.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.science_outlined,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No lab reports found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._filteredReports.map((report) => _buildReportCard(report)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color,
      {bool filled = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          border: filled ? null : Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 22,
                color: filled ? Colors.white.withOpacity(0.8) : color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: filled ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: filled ? Colors.white.withOpacity(0.8) : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final status = report['status'] as String;
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.amber;
        statusIcon = Icons.schedule;
        break;
      case 'processing':
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_top;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    final date = report['date'] as DateTime;
    final dateStr =
        '${_monthName(date.month)} ${date.day}, ${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.biotech,
                  color: AppConstants.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['testName'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report['labName'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${report['amount']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 13, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (status == 'completed' && report['hasReport'] == true) ...[
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Report'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.download, size: 18),
                ),
              ],
            ),
          ],
          if (status == 'pending') ...[
            const Divider(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Reschedule'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }
}
