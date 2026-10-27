import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../core/utils/server_dates.dart';
import '../../features/onboarding/onboarding_widgets.dart' show AuthNote;
import '../../providers/prescription_provider.dart';
import '../../services/patient_records_service.dart';
import '../pathology/diagnostic_order_details_screen.dart';
import '../pathology/pathology_screen.dart';
import '../payments/payments_screen.dart';
import '../physiotherapy/physiotherapy_screen.dart';
import '../prescriptions/prescriptions_screen.dart';

/// The Records tab: the patient's health at a glance (vitals, conditions,
/// allergies, medicines) — which doctors see before a visit — plus reports,
/// prescriptions and bills.
class HealthRecordsScreen extends StatefulWidget {
  const HealthRecordsScreen({super.key});

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  Map<String, dynamic>? _profile;
  PatientRecordsBundle? _bundle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        PatientRecordsService.instance.profile(),
        PatientRecordsService.instance.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _bundle = results[1] as PatientRecordsBundle;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), ''));
    }
  }

  void _push(Widget w) => Navigator.of(context).push(AppPageRoute(builder: (_) => w));

  Future<void> _editVitals() async {
    final saved = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VitalsSheet(profile: _profile ?? const {}),
    );
    if (saved != null && mounted) setState(() => _profile = saved);
  }

  Future<void> _add(String type) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddRecordSheet(type: type),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final rxCount = context.watch<PrescriptionProvider>().allPrescriptions.length;
    final history = _bundle?.medicalHistory ?? const {};
    final reports = _bundle?.labReports ?? const [];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppTopBar(title: 'Health records', showBack: Navigator.of(context).canPop()),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: _bundle == null && _error == null
            ? const AppDetailSkeleton()
            : _bundle == null
            ? ListView(
                children: [
                  AppEmptyState(
                    illustration: Illustrations.offline,
                    title: 'Couldn’t load your records',
                    message: _error,
                    actionLabel: 'Try again',
                    onAction: _load,
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  AppEntrance(child: _Vitals(profile: _profile ?? const {}, onEdit: _editVitals)),
                  const SizedBox(height: 14),
                  AppEntrance(
                    index: 1,
                    child: Row(
                      children: [
                        _Shortcut(LucideIcons.fileText, 'Prescriptions', '$rxCount', AppColors.brand, () => _push(const PrescriptionsScreen())),
                        const SizedBox(width: 10),
                        _Shortcut(LucideIcons.flaskConical, 'Lab reports', '${reports.length}', ModuleAccent.lab.color, () => _push(const PathologyScreen())),
                        const SizedBox(width: 10),
                        _Shortcut(LucideIcons.receiptIndianRupee, 'Bills', '${_bundle!.invoices.length}', AppColors.health, () => _push(const PaymentsScreen())),
                        const SizedBox(width: 10),
                        _Shortcut(LucideIcons.dumbbell, 'Exercises', '', ModuleAccent.physio.color, () => _push(const PhysiotherapyScreen())),
                      ],
                    ),
                  ),
                  _Group(
                    title: 'Allergies',
                    icon: LucideIcons.shieldAlert,
                    tone: AppColors.error,
                    empty: 'No allergies noted',
                    items: [
                      for (final a in mapsOf(history['allergies']))
                        (a['allergen']?.toString() ?? '', [a['reaction'], a['severity'] == null ? null : sentenceCase(a['severity'].toString())].where((e) => e != null && e.toString().isNotEmpty).join(' · ')),
                    ],
                    onAdd: () => _add('allergy'),
                  ),
                  _Group(
                    title: 'Conditions',
                    icon: LucideIcons.heartPulse,
                    tone: AppColors.brand,
                    empty: 'No conditions noted',
                    items: [
                      for (final c in mapsOf(history['chronicConditions']))
                        (c['condition']?.toString() ?? '', (c['currentStatus'] ?? '').toString()),
                      for (final c in mapsOf(history['medicalHistory']))
                        (c['condition']?.toString() ?? '', [c['status'] == null ? null : sentenceCase(c['status'].toString()), c['diagnosedDate'] == null ? null : DateFormat('MMM y').format(DateTime.parse(c['diagnosedDate'].toString()).toLocal())].where((e) => e != null).join(' · ')),
                    ],
                    onAdd: () => _add('medicalHistory'),
                  ),
                  _Group(
                    title: 'Current medicines',
                    icon: LucideIcons.pill,
                    tone: ModuleAccent.pharmacy.color,
                    empty: 'No regular medicines noted',
                    items: [
                      for (final m in mapsOf(history['currentMedications']))
                        (m['medicineName']?.toString() ?? '', [m['dosage'], m['frequency']].where((e) => e != null && e.toString().isNotEmpty).join(' · ')),
                    ],
                    onAdd: () => _add('medication'),
                  ),
                  if (reports.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    AppSectionHeader(title: 'Recent lab reports', action: 'All', onAction: () => _push(const PathologyScreen()), padding: const EdgeInsets.only(bottom: 10)),
                    for (final r in reports.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () => _push(DiagnosticOrderDetailsScreen(orderId: idOf(r))),
                          child: Row(
                            children: [
                              Icon(LucideIcons.fileChartColumn, size: 19, color: ModuleAccent.lab.color),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mapsOf(r['tests']).map((t) => t['testName']).where((n) => n != null).join(', '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: AppColors.textStrong),
                                    ),
                                    Text(
                                      [mapOf(r['pathologyId'])['labName'], if (serverDay(r['scheduledDate']) != null) DateFormat('d MMM y').format(serverDay(r['scheduledDate'])!)].where((e) => e != null).join(' · '),
                                      style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              PatientStatus.of(r['status']?.toString()).pill(icon: false),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Vitals extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;
  const _Vitals({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final h = asDouble(profile['height']);
    final w = asDouble(profile['weight']);
    final bmi = h > 0 && w > 0 ? w / ((h / 100) * (h / 100)) : 0.0;
    final blood = (profile['bloodGroup'] ?? '').toString();
    final age = (profile['age'] as num?)?.toInt();
    final (bmiLabel, bmiColor) = bmi == 0
        ? ('', AppColors.textSecondary)
        : bmi < 18.5
        ? ('Underweight', AppColors.warning)
        : bmi < 25
        ? ('Healthy', AppColors.health)
        : bmi < 30
        ? ('Overweight', AppColors.warning)
        : ('Obese', AppColors.error);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE6F4FC), Color(0xFFF5FAFE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Your vitals', style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
              const Spacer(),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.pencil, size: 14),
                label: const Text('Update'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 32)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Vital('Blood', blood.isEmpty || blood == 'Unknown' ? '—' : blood, LucideIcons.droplet, AppColors.error),
              _Vital('Height', h > 0 ? '${h.round()} cm' : '—', LucideIcons.ruler, AppColors.brand),
              _Vital('Weight', w > 0 ? '${w.toStringAsFixed(w % 1 == 0 ? 0 : 1)} kg' : '—', LucideIcons.scale, AppColors.brand),
              _Vital('BMI', bmi > 0 ? bmi.toStringAsFixed(1) : '—', LucideIcons.activity, bmiColor, caption: bmiLabel),
            ],
          ),
          if (age != null || (profile['gender'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              [if (age != null) '$age years', if ((profile['gender'] ?? '').toString().isNotEmpty) sentenceCase(profile['gender'].toString().replaceAll('prefer_not_to_say', ''))]
                  .where((e) => e.isNotEmpty)
                  .join(' · '),
              style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Vital extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String caption;
  const _Vital(this.label, this.value, this.icon, this.color, {this.caption = ''});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 6),
        Text(value, style: AppType.sans(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
        Text(caption.isNotEmpty ? caption : label, style: AppType.sans(fontSize: AppType.micro + 0.5, fontWeight: FontWeight.w600, color: caption.isNotEmpty ? color : AppColors.textSecondary)),
      ],
    ),
  );
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final Color color;
  final VoidCallback onTap;
  const _Shortcut(this.icon, this.label, this.count, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
    child: AppPressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderStrong)),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(fontSize: AppType.micro + 0.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            if (count.isNotEmpty) Text(count, style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
          ],
        ),
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color tone;
  final String empty;
  final List<(String, String)> items;
  final VoidCallback onAdd;
  const _Group({required this.title, required this.icon, required this.tone, required this.empty, required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: tone),
            const SizedBox(width: 8),
            Text(title, style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 15),
              label: const Text('Add'),
              style: TextButton.styleFrom(minimumSize: const Size(0, 32)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (items.where((i) => i.$1.isNotEmpty).isEmpty)
          Text(empty, style: AppType.sans(fontSize: AppType.body, color: AppColors.textTertiary))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, detail) in items.where((i) => i.$1.isNotEmpty))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Color.alphaBlend(tone.withValues(alpha: 0.07), Colors.white), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w700, color: AppColors.textStrong)),
                      if (detail.isNotEmpty) Text(detail, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

class _VitalsSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  const _VitalsSheet({required this.profile});

  @override
  State<_VitalsSheet> createState() => _VitalsSheetState();
}

class _VitalsSheetState extends State<_VitalsSheet> {
  static const _groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  late String? _blood = _groups.contains(widget.profile['bloodGroup']) ? widget.profile['bloodGroup'].toString() : null;
  late final _height = TextEditingController(text: asDouble(widget.profile['height']) > 0 ? '${asDouble(widget.profile['height']).round()}' : '');
  late final _weight = TextEditingController(text: asDouble(widget.profile['weight']) > 0 ? '${widget.profile['weight']}' : '');
  late final _ecName = TextEditingController(text: mapOf(widget.profile['emergencyContact'])['name']?.toString() ?? '');
  late final _ecPhone = TextEditingController(text: mapOf(widget.profile['emergencyContact'])['phone']?.toString() ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_height, _weight, _ecName, _ecPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final h = double.tryParse(_height.text.trim());
    final w = double.tryParse(_weight.text.trim());
    if ((h != null && (h < 30 || h > 250)) || (w != null && (w < 2 || w > 300))) {
      setState(() => _error = 'Check the height (cm) and weight (kg)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await PatientRecordsService.instance.updateProfile({
        'bloodGroup': ?_blood,
        'height': ?h,
        'weight': ?w,
        if (h != null && w != null) 'bmi': double.parse((w / ((h / 100) * (h / 100))).toStringAsFixed(1)),
        if (_ecName.text.trim().isNotEmpty || _ecPhone.text.trim().isNotEmpty)
          'emergencyContact': {
            ...mapOf(widget.profile['emergencyContact']),
            'name': _ecName.text.trim(),
            'phone': _ecPhone.text.trim(),
          },
      });
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your vitals', style: AppType.sans(fontSize: AppType.heading + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
            const SizedBox(height: 14),
            Text('Blood group', style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final g in _groups) AppFilterChip(label: g, selected: _blood == g, onTap: () => setState(() => _blood = g))],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Height (cm)',
                    controller: _height,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    margin: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    label: 'Weight (kg)',
                    controller: _weight,
                    isDecimal: true,
                    margin: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Emergency contact', style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: AppTextField(label: '', hint: 'Name', controller: _ecName, textCapitalization: TextCapitalization.words, margin: EdgeInsets.zero)),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    label: '',
                    hint: 'Phone',
                    controller: _ecPhone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    margin: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[const SizedBox(height: 12), AuthNote.error(_error!)],
            const SizedBox(height: 18),
            AppButton(label: 'Save', loading: _busy, onPressed: _save),
          ],
        ),
      ),
    ),
  );
}

class _AddRecordSheet extends StatefulWidget {
  final String type; // allergy | medicalHistory | medication
  const _AddRecordSheet({required this.type});

  @override
  State<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<_AddRecordSheet> {
  final _name = TextEditingController();
  final _detail = TextEditingController();
  final _extra = TextEditingController();
  String? _choice;
  bool _busy = false;
  String? _error;

  (String, String, String, String?, List<(String, String)>) get _config => switch (widget.type) {
    'allergy' => ('Add an allergy', 'Allergic to (e.g. penicillin, peanuts)', 'Reaction (e.g. rash)', 'Severity', [('mild', 'Mild'), ('moderate', 'Moderate'), ('severe', 'Severe')]),
    'medication' => ('Add a medicine you take', 'Medicine name', 'Dose (e.g. 500 mg)', null, const <(String, String)>[]),
    _ => ('Add a condition', 'Condition (e.g. diabetes, asthma)', 'Notes (optional)', 'Status', [('active', 'Active'), ('chronic', 'Long-term'), ('resolved', 'Resolved')]),
  };

  @override
  void dispose() {
    _name.dispose();
    _detail.dispose();
    _extra.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Add a name');
      return;
    }
    final data = switch (widget.type) {
      'allergy' => {'allergen': name, 'reaction': _detail.text.trim(), 'severity': ?_choice},
      'medication' => {'medicineName': name, 'dosage': _detail.text.trim(), 'frequency': _extra.text.trim()},
      _ => {'condition': name, 'notes': _detail.text.trim(), 'status': ?_choice},
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PatientRecordsService.instance.addMedicalRecord(recordType: widget.type, data: data);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, nameHint, detailHint, choiceLabel, choices) = _config;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppType.sans(fontSize: AppType.heading + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
              const SizedBox(height: 14),
              AppTextField(label: '', hint: nameHint, controller: _name, textCapitalization: TextCapitalization.sentences, margin: const EdgeInsets.only(bottom: 10)),
              AppTextField(label: '', hint: detailHint, controller: _detail, textCapitalization: TextCapitalization.sentences, margin: const EdgeInsets.only(bottom: 10)),
              if (widget.type == 'medication')
                AppTextField(label: '', hint: 'How often (e.g. twice a day)', controller: _extra, margin: const EdgeInsets.only(bottom: 10)),
              if (choiceLabel != null) ...[
                Text(choiceLabel, style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final (i, (v, l)) in choices.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: AppFilterChip(label: l, selected: _choice == v, block: true, onTap: () => setState(() => _choice = v))),
                    ],
                  ],
                ),
              ],
              if (_error != null) ...[const SizedBox(height: 12), AuthNote.error(_error!)],
              const SizedBox(height: 18),
              AppButton(label: 'Save', loading: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
