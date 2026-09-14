import 'package:aadya_plus/providers/lab_test_provider.dart';
import 'package:aadya_plus/screens/payments/payment_checkout_screen.dart';
import 'package:aadya_plus/services/patient_records_service.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DiagnosticOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const DiagnosticOrderDetailsScreen({super.key, required this.orderId});
  @override
  State<DiagnosticOrderDetailsScreen> createState() => _DiagnosticOrderDetailsScreenState();
}

class _DiagnosticOrderDetailsScreenState extends State<DiagnosticOrderDetailsScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final order = await context.read<LabTestProvider>().getOrder(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Cancel diagnostic booking?'),
      content: const Text('Cancellation is only allowed before sample processing begins and is subject to the lab cancellation window.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep booking')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel'))],
    ));
    if (ok != true) return;
    setState(() => _actionBusy = true);
    try { await context.read<LabTestProvider>().cancelOrder(widget.orderId); await _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => _actionBusy = false); }
  }

  Future<void> _reschedule() async {
    final order = _order!;
    final lab = order['pathologyId'];
    final labId = lab is Map ? (lab['_id'] ?? '').toString() : lab.toString();
    DateTime date = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
    if (picked == null) return;
    date = picked;
    if (!mounted) return;
    setState(() => _actionBusy = true);
    try {
      final slots = await context.read<LabTestProvider>().slots(labId, date);
      final available = slots.where((s) => s['isAvailable'] == true).toList();
      if (!mounted) return;
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No available slots on that date.')));
        return;
      }
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (_) => SafeArea(child: ListView(shrinkWrap: true, children: [
          const ListTile(title: Text('Select a new slot', style: TextStyle(fontWeight: FontWeight.w900))),
          ...available.map((s) => ListTile(title: Text('${s['startTime']} - ${s['endTime']}'), onTap: () => Navigator.pop(context, s))),
        ])),
      );
      if (selected == null || !mounted) return;
      await context.read<LabTestProvider>().reschedule(id: widget.orderId, date: date, startTime: selected['startTime'].toString(), endTime: selected['endTime'].toString());
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(o?['labTestNumber']?.toString() ?? 'Diagnostic Order')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text(_error!)) : o == null ? const SizedBox() : RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _card('Current status', [
            Text(_label(o['status']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppConstants.primaryColor)),
            Text('${_label(o['type'])} • Payment ${_label(o['paymentStatus'])}'),
            if (o['type'] == 'home_collection') Text('Collection: ${_label(o['collectionStatus'])}'),
            if (o['assignedPhlebotomistId'] is Map) Text('Collector: ${o['assignedPhlebotomistId']['name'] ?? ''} ${o['assignedPhlebotomistId']['phone'] ?? ''}'),
          ]),
          const SizedBox(height: 12),
          _card('Booking', [
            Text('Date: ${_date(o['scheduledDate'])}'),
            Text('Time: ${o['startTime'] ?? o['scheduledTime'] ?? ''} - ${o['endTime'] ?? ''}'),
            if ((o['instructions'] ?? '').toString().isNotEmpty) Text((o['instructions']).toString(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          _card('Tests / packages', [
            ..._list(o['packages']).map((x) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.inventory_2_outlined), title: Text((x['packageName'] ?? 'Package').toString()), trailing: Text('₹${_double(x['price']).toStringAsFixed(0)}'))),
            ..._list(o['tests']).map((x) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.biotech_outlined), title: Text((x['testName'] ?? 'Test').toString()), subtitle: Text(_label(x['status'])))),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total', style: TextStyle(fontWeight: FontWeight.w800)), Text('₹${_double(o['totalAmount']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]),
          ]),
          const SizedBox(height: 12),
          _card('Timeline', [
            ..._list(o['statusHistory']).reversed.map((h) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.circle, size: 12, color: AppConstants.primaryColor), title: Text(_label(h['status'])), subtitle: Text((h['note'] ?? '').toString()))),
          ]),
          const SizedBox(height: 14),
          if (o['paymentStatus'] == 'pending' && o['status'] != 'cancelled')
            ElevatedButton.icon(
              onPressed: _actionBusy ? null : () async {
                final paid = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PaymentCheckoutScreen(entityType: 'labtest', entityId: widget.orderId, title: 'Diagnostic order', expectedAmount: _double(o['totalAmount']))));
                if (paid == true) _load();
              },
              icon: const Icon(Icons.lock_outline), label: const Text('Pay securely online'),
            ),
          if (o['reportFile'] is Map || (o['reportUrl'] ?? '').toString().isNotEmpty || o['status'] == 'completed')
            ElevatedButton.icon(
              onPressed: _actionBusy ? null : () async {
                try { await PatientRecordsService.instance.downloadAndOpenLabReport(widget.orderId); }
                catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
              },
              icon: const Icon(Icons.download_outlined), label: const Text('Download secure report'),
            ),
          if (['scheduled', 'requested'].contains(o['status'])) ...[
            OutlinedButton.icon(onPressed: _actionBusy ? null : _reschedule, icon: const Icon(Icons.event_repeat_outlined), label: const Text('Reschedule')),
            OutlinedButton.icon(onPressed: _actionBusy ? null : _cancel, icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel booking')),
          ],
        ]),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...children]));
  static List<Map<String, dynamic>> _list(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  static String _label(dynamic value) => value.toString().replaceAll('_', ' ').split(' ').map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}').join(' ');
  static String _date(dynamic value) { final d = DateTime.tryParse(value?.toString() ?? ''); return d == null ? '' : '${d.day}/${d.month}/${d.year}'; }
}
