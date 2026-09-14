import 'package:aadya_plus/providers/lab_test_provider.dart';
import 'package:aadya_plus/screens/payments/payment_checkout_screen.dart';
import 'package:aadya_plus/screens/pathology/pathology_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DiagnosticBookingScreen extends StatefulWidget {
  final Map<String, dynamic> catalogItem;
  const DiagnosticBookingScreen({super.key, required this.catalogItem});
  @override
  State<DiagnosticBookingScreen> createState() => _DiagnosticBookingScreenState();
}

class _DiagnosticBookingScreenState extends State<DiagnosticBookingScreen> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _type = 'lab_visit';
  List<Map<String, dynamic>> _slots = [];
  Map<String, dynamic>? _slot;
  bool _loadingSlots = false;
  bool _booking = false;
  String? _error;

  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _instructions = TextEditingController();

  bool get _homeSupported => widget.catalogItem['homeCollectionAvailable'] == true;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _loadSlots()); }

  @override
  void dispose() {
    for (final c in [_contact, _phone, _line1, _line2, _city, _state, _pincode, _instructions]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() { _loadingSlots = true; _slot = null; _error = null; });
    try {
      final slots = await context.read<LabTestProvider>().slots((widget.catalogItem['labId'] ?? '').toString(), _date);
      if (mounted) setState(() => _slots = slots.where((s) => s['isAvailable'] == true).toList());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
    if (picked != null) { setState(() => _date = picked); await _loadSlots(); }
  }

  Future<void> _book() async {
    if (_slot == null) { setState(() => _error = 'Select an available collection slot.'); return; }
    Map<String, dynamic>? address;
    if (_type == 'home_collection') {
      if (_line1.text.trim().isEmpty || _city.text.trim().isEmpty || _state.text.trim().isEmpty || _pincode.text.trim().length != 6) {
        setState(() => _error = 'Complete home collection address and 6-digit pincode are required.');
        return;
      }
      address = {
        'contactName': _contact.text.trim(), 'phone': _phone.text.trim(),
        'line1': _line1.text.trim(), 'line2': _line2.text.trim(),
        'city': _city.text.trim(), 'state': _state.text.trim(), 'pincode': _pincode.text.trim(),
      };
    }
    setState(() { _booking = true; _error = null; });
    try {
      final order = await context.read<LabTestProvider>().book(
        catalogItem: widget.catalogItem,
        date: _date,
        startTime: (_slot!['startTime'] ?? '').toString(),
        endTime: (_slot!['endTime'] ?? '').toString(),
        type: _type,
        collectionAddress: address,
        patientInstructions: _instructions.text,
      );
      if (!mounted) return;
      final id = (order['_id'] ?? '').toString();
      final amount = _double(order['totalAmount']);
      final payNow = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: const Text('Diagnostic booking confirmed'),
        content: Text('Amount: ₹${amount.toStringAsFixed(2)}\nWould you like to pay securely now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Pay later')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pay now')),
        ],
      ));
      if (!mounted) return;
      if (payNow == true && amount > 0) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentCheckoutScreen(entityType: 'labtest', entityId: id, title: 'Diagnostic order', expectedAmount: amount)));
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PathologyScreen()), (route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.catalogItem['item'] is Map ? Map<String, dynamic>.from(widget.catalogItem['item']) : <String, dynamic>{};
    final isPackage = widget.catalogItem['kind'] == 'package';
    final name = (isPackage ? item['packageName'] : item['testName'])?.toString() ?? 'Diagnostic item';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Book Diagnostic Test')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _card([Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text((widget.catalogItem['labName'] ?? '').toString()), const SizedBox(height: 6), Text('₹${_double(item['price']).toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, color: AppConstants.primaryColor, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 12),
        _card([
          const Text('Collection type', style: TextStyle(fontWeight: FontWeight.w900)),
          RadioListTile(value: 'lab_visit', groupValue: _type, title: const Text('Visit lab'), onChanged: (v) => setState(() => _type = v!)),
          RadioListTile(value: 'home_collection', groupValue: _type, title: const Text('Home collection'), subtitle: !_homeSupported ? const Text('Not available for this lab') : null, onChanged: !_homeSupported ? null : (v) => setState(() => _type = v!)),
        ]),
        if (_type == 'home_collection') ...[
          const SizedBox(height: 12),
          _card([
            const Text('Home collection address', style: TextStyle(fontWeight: FontWeight.w900)),
            TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact name')),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: _line1, decoration: const InputDecoration(labelText: 'Address line 1')),
            TextField(controller: _line2, decoration: const InputDecoration(labelText: 'Address line 2')),
            TextField(controller: _city, decoration: const InputDecoration(labelText: 'City')),
            TextField(controller: _state, decoration: const InputDecoration(labelText: 'State')),
            TextField(controller: _pincode, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Pincode')),
          ]),
        ],
        const SizedBox(height: 12),
        _card([
          const Text('Date & slot', style: TextStyle(fontWeight: FontWeight.w900)),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_month), title: Text('${_date.day}/${_date.month}/${_date.year}'), trailing: TextButton(onPressed: _pickDate, child: const Text('Change'))),
          if (_loadingSlots) const LinearProgressIndicator(),
          if (!_loadingSlots && _slots.isEmpty) const Text('No available slots on this date.'),
          Wrap(spacing: 8, runSpacing: 8, children: _slots.map((s) => ChoiceChip(
            label: Text('${s['startTime']} - ${s['endTime']}'),
            selected: identical(_slot, s),
            onSelected: (_) => setState(() => _slot = s),
          )).toList()),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _instructions, maxLines: 2, decoration: const InputDecoration(labelText: 'Instructions for lab/collector (optional)', border: OutlineInputBorder())),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _booking ? null : _book,
          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
          child: Text(_booking ? 'Booking...' : 'Book diagnostic order'),
        ),
      ]),
    );
  }

  Widget _card(List<Widget> children) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}
