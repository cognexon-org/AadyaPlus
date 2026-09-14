import 'package:aadya_plus/providers/pharmacy_provider.dart';
import 'package:aadya_plus/screens/payments/payment_checkout_screen.dart';
import 'package:aadya_plus/screens/pharmacy/pharmacy_orders_screen.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EPharmacyCheckoutScreen extends StatefulWidget {
  const EPharmacyCheckoutScreen({super.key});
  @override
  State<EPharmacyCheckoutScreen> createState() => _EPharmacyCheckoutScreenState();
}

class _EPharmacyCheckoutScreenState extends State<EPharmacyCheckoutScreen> {
  String? _addressId;
  String _paymentMethod = 'cod';
  String? _rxChoice;
  final _coupon = TextEditingController();
  final _instructions = TextEditingController();
  Map<String, dynamic>? _quote;
  bool _busy = false;
  String? _error;

  bool get _needsRx {
    final p = context.read<PharmacyProvider>();
    return p.cartItems.any((line) {
      final medicine = line['medicine'];
      return medicine is Map && medicine['prescriptionRequired'] == true;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<PharmacyProvider>();
      await p.loadCheckoutData();
      if (!mounted) return;
      final defaults = p.addresses.where((a) => a['isDefault'] == true).toList();
      setState(() {
        if (defaults.isNotEmpty) _addressId = _id(defaults.first);
        else if (p.addresses.isNotEmpty) _addressId = _id(p.addresses.first);
      });
    });
  }

  @override
  void dispose() {
    _coupon.dispose();
    _instructions.dispose();
    super.dispose();
  }

  String? get _prescriptionId => _rxChoice?.startsWith('rx:') == true ? _rxChoice!.substring(3) : null;
  String? get _uploadId => _rxChoice?.startsWith('upload:') == true ? _rxChoice!.substring(7) : null;

  Future<void> _review() async {
    if (_addressId == null) {
      setState(() => _error = 'Add and select a delivery address.');
      return;
    }
    if (_needsRx && _rxChoice == null) {
      setState(() => _error = 'Select an Aadya prescription or upload an external prescription.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final quote = await context.read<PharmacyProvider>().quote(
        addressId: _addressId!,
        paymentMethod: _paymentMethod,
        couponCode: _coupon.text,
        prescriptionId: _prescriptionId,
        prescriptionUploadId: _uploadId,
      );
      if (mounted) setState(() => _quote = quote);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _placeOrder() async {
    if (_quote == null) {
      await _review();
      if (_quote == null) return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final order = await context.read<PharmacyProvider>().placeOrder(
        addressId: _addressId!,
        paymentMethod: _paymentMethod,
        couponCode: _coupon.text,
        prescriptionId: _prescriptionId,
        prescriptionUploadId: _uploadId,
        deliveryInstructions: _instructions.text,
      );
      final id = _id(order);
      final total = _double(order['totalAmount']);
      if (!mounted) return;
      if (_paymentMethod == 'online') {
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentCheckoutScreen(
              entityType: 'pharmacy_order',
              entityId: id,
              title: 'Medicine order ${(order['orderNumber'] ?? '').toString()}',
              expectedAmount: total,
            ),
          ),
        );
        if (paid != true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order created. Payment is still pending; you can complete it from the order screen.')),
          );
        }
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PharmacyOrdersScreen()),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadPrescription() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final upload = await context.read<PharmacyProvider>().uploadPrescription(path);
      if (!mounted) return;
      setState(() => _rxChoice = 'upload:${_id(upload)}');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription uploaded for pharmacy review.')));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAddress() async {
    final contact = TextEditingController();
    final phone = TextEditingController();
    final line1 = TextEditingController();
    final line2 = TextEditingController();
    final city = TextEditingController();
    final state = TextEditingController();
    final pincode = TextEditingController();
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add delivery address'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact name')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: line1, decoration: const InputDecoration(labelText: 'Address line 1')),
            TextField(controller: line2, decoration: const InputDecoration(labelText: 'Address line 2')),
            TextField(controller: city, decoration: const InputDecoration(labelText: 'City')),
            TextField(controller: state, decoration: const InputDecoration(labelText: 'State')),
            TextField(controller: pincode, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Pincode')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (contact.text.trim().isEmpty || phone.text.trim().isEmpty || line1.text.trim().isEmpty || city.text.trim().isEmpty || state.text.trim().isEmpty || pincode.text.trim().length != 6) return;
              try {
                final address = await context.read<PharmacyProvider>().createAddress({
                  'label': 'Home', 'contactName': contact.text.trim(), 'phone': phone.text.trim(),
                  'line1': line1.text.trim(), 'line2': line2.text.trim(), 'city': city.text.trim(),
                  'state': state.text.trim(), 'pincode': pincode.text.trim(), 'country': 'India', 'isDefault': true,
                });
                if (context.mounted) Navigator.pop(context, address);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (created != null && mounted) setState(() => _addressId = _id(created));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PharmacyProvider>();
    final quote = _quote;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Medicine Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Delivery address', [
            if (provider.addresses.isEmpty)
              const Text('No saved address yet.')
            else
              ...provider.addresses.map((a) => RadioListTile<String>(
                value: _id(a),
                groupValue: _addressId,
                onChanged: (v) => setState(() { _addressId = v; _quote = null; }),
                title: Text('${a['label'] ?? 'Address'} • ${a['contactName'] ?? ''}'),
                subtitle: Text('${a['line1'] ?? ''}, ${a['city'] ?? ''}, ${a['state'] ?? ''} ${a['pincode'] ?? ''}'),
              )),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _addAddress, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Add address'))),
          ]),
          if (_needsRx) ...[
            const SizedBox(height: 12),
            _section('Prescription', [
              const Text('One or more medicines require a prescription.'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _rxChoice,
                decoration: const InputDecoration(labelText: 'Select prescription', border: OutlineInputBorder()),
                items: [
                  ...provider.prescriptions.map((p) => DropdownMenuItem(
                    value: 'rx:${_id(p)}',
                    child: Text('Aadya Rx ${p['prescriptionNumber'] ?? _id(p)}'),
                  )),
                  ...provider.uploads.map((u) => DropdownMenuItem(
                    value: 'upload:${_id(u)}',
                    child: Text('Upload ${u['originalName'] ?? _id(u)} (${u['status'] ?? 'pending'})'),
                  )),
                ],
                onChanged: (v) => setState(() { _rxChoice = v; _quote = null; }),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _busy ? null : _uploadPrescription, icon: const Icon(Icons.upload_file), label: const Text('Upload external prescription')),
            ]),
          ],
          const SizedBox(height: 12),
          _section('Payment & offer', [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cod', label: Text('COD'), icon: Icon(Icons.payments_outlined)),
                ButtonSegment(value: 'online', label: Text('Online'), icon: Icon(Icons.lock_outline)),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (s) => setState(() { _paymentMethod = s.first; _quote = null; }),
            ),
            const SizedBox(height: 12),
            TextField(controller: _coupon, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Coupon code (optional)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _instructions, maxLines: 2, decoration: const InputDecoration(labelText: 'Delivery instructions (optional)', border: OutlineInputBorder())),
          ]),
          const SizedBox(height: 12),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          if (quote != null) ...[
            _section('Server checkout quote', [
              _row('Subtotal', quote['subtotal']),
              _row('Medicine discount', -_double(quote['medicineDiscount'])),
              _row('Coupon discount', -_double(quote['couponDiscount'])),
              _row('Tax', quote['tax']),
              _row('Delivery fee', quote['deliveryFee']),
              const Divider(),
              _row('Total', quote['totalAmount'], bold: true),
              if (quote['prescriptionRequired'] == true)
                Text('Prescription: ${quote['prescriptionStatus']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
          ],
          OutlinedButton(onPressed: _busy ? null : _review, child: Text(_busy ? 'Checking...' : 'Review server price & stock')),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _busy ? null : _placeOrder,
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(_paymentMethod == 'online' ? 'Place order & pay' : 'Place COD order'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 10), ...children]),
      );

  Widget _row(String label, dynamic value, {bool bold = false}) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
        Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
      ]),
    );
  }

  static String _id(Map<String, dynamic> m) => (m['_id'] ?? m['id'] ?? '').toString();
  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}
