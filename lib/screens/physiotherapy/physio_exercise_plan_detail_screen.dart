import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/physio_exercise_service.dart';
import '../../utils/constants.dart';

class PhysioExercisePlanDetailScreen extends StatefulWidget {
  final String planId;
  const PhysioExercisePlanDetailScreen({super.key, required this.planId});

  @override
  State<PhysioExercisePlanDetailScreen> createState() => _PhysioExercisePlanDetailScreenState();
}

class _PhysioExercisePlanDetailScreenState extends State<PhysioExercisePlanDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _plan;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await PhysioExerciseService.instance.getPlan(widget.planId);
      if (!mounted) return;
      setState(() {
        _plan = data['plan'] is Map ? Map<String, dynamic>.from(data['plan']) : null;
        _summary = data['summary'] is Map ? Map<String, dynamic>.from(data['summary']) : {};
        _logs = (data['progress'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logExercise(Map<String, dynamic> item) async {
    final sets = TextEditingController(text: '${item['sets'] ?? 0}');
    final reps = TextEditingController(text: '${item['reps'] ?? 0}');
    final duration = TextEditingController(text: '${item['durationSec'] ?? 0}');
    final notes = TextEditingController();
    int? painBefore;
    int? painAfter;
    String difficulty = 'about_right';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final exercise = item['exerciseId'] is Map
              ? Map<String, dynamic>.from(item['exerciseId'])
              : <String, dynamic>{};
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Log ${exercise['name'] ?? 'Exercise'}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _numberField(sets, 'Sets')),
                    const SizedBox(width: 10),
                    Expanded(child: _numberField(reps, 'Reps')),
                    const SizedBox(width: 10),
                    Expanded(child: _numberField(duration, 'Seconds')),
                  ]),
                  const SizedBox(height: 14),
                  const Text('Pain before (0-10)'),
                  Slider(
                    min: 0,
                    max: 10,
                    divisions: 10,
                    value: (painBefore ?? 0).toDouble(),
                    label: '${painBefore ?? 0}',
                    onChanged: (v) => setSheetState(() => painBefore = v.round()),
                  ),
                  const Text('Pain after (0-10)'),
                  Slider(
                    min: 0,
                    max: 10,
                    divisions: 10,
                    value: (painAfter ?? 0).toDouble(),
                    label: '${painAfter ?? 0}',
                    onChanged: (v) => setSheetState(() => painAfter = v.round()),
                  ),
                  DropdownButtonFormField<String>(
                    value: difficulty,
                    decoration: const InputDecoration(labelText: 'How did it feel?'),
                    items: const [
                      DropdownMenuItem(value: 'easy', child: Text('Easy')),
                      DropdownMenuItem(value: 'about_right', child: Text('About right')),
                      DropdownMenuItem(value: 'hard', child: Text('Hard')),
                    ],
                    onChanged: (v) => setSheetState(() => difficulty = v ?? 'about_right'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save progress'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved == true) {
      try {
        await PhysioExerciseService.instance.logProgress(
          widget.planId,
          planItemId: item['_id'].toString(),
          setsCompleted: int.tryParse(sets.text) ?? 0,
          repsCompleted: int.tryParse(reps.text) ?? 0,
          durationSec: int.tryParse(duration.text) ?? 0,
          painBefore: painBefore,
          painAfter: painAfter,
          perceivedDifficulty: difficulty,
          notes: notes.text,
        );
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress saved')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      }
    }

    sets.dispose();
    reps.dispose();
    duration.dispose();
    notes.dispose();
  }

  static Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final plan = _plan;
    if (plan == null) {
      return const Scaffold(body: Center(child: Text('Exercise plan not found')));
    }

    final physio = plan['physioId'] is Map
        ? Map<String, dynamic>.from(plan['physioId'])
        : <String, dynamic>{};
    final exercises = plan['exercises'] as List? ?? const [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: Text(plan['title'] ?? 'Exercise Plan'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  physio['name'] ?? 'Your physiotherapist',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if ((physio['specialization'] ?? '').toString().isNotEmpty)
                  Text(physio['specialization'].toString()),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _chip('${exercises.length} exercises'),
                  _chip('${_summary['completedLogs'] ?? 0} completed'),
                  _chip((plan['status'] ?? 'active').toString().toUpperCase()),
                ]),
                if ((plan['instructions'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(plan['instructions'].toString()),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Your exercises', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...exercises.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              final exercise = item['exerciseId'] is Map
                  ? Map<String, dynamic>.from(item['exerciseId'])
                  : <String, dynamic>{};
              final steps = exercise['instructions'] as List? ?? const [];
              final precautions = exercise['precautions'] as List? ?? const [];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        exercise['name'] ?? 'Exercise',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: plan['status'] == 'active' ? () => _logExercise(item) : null,
                      child: const Text('Log'),
                    ),
                  ]),
                  if ((exercise['description'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(exercise['description'].toString()),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${item['sets'] ?? 0} sets • ${item['reps'] ?? 0} reps${(item['durationSec'] ?? 0) > 0 ? ' • ${item['durationSec']} sec' : ''}',
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                  if ((item['frequency'] ?? '').toString().isNotEmpty)
                    Text(item['frequency'].toString(), style: TextStyle(color: AppConstants.primaryColor)),
                  if ((item['notes'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Note: ${item['notes']}'),
                    ),
                  if (steps.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Instructions', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...steps.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${entry.key + 1}. ${entry.value}'),
                    )),
                  ],
                  if (precautions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Precautions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ...precautions.map((p) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• $p'),
                    )),
                  ],
                ]),
              );
            }),
            const SizedBox(height: 20),
            const Text('Recent activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No exercise sessions logged yet.'),
              )
            else
              ..._logs.take(20).map((log) {
                final ex = log['exerciseId'] is Map
                    ? Map<String, dynamic>.from(log['exerciseId'])
                    : <String, dynamic>{};
                final date = DateTime.tryParse(log['performedAt']?.toString() ?? '');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(ex['name'] ?? 'Exercise'),
                  subtitle: Text(
                    '${date == null ? '' : DateFormat('dd MMM, hh:mm a').format(date.toLocal())} • '
                    '${log['setsCompleted'] ?? 0} sets • ${log['repsCompleted'] ?? 0} reps',
                  ),
                  trailing: log['painAfter'] == null ? null : Text('Pain ${log['painAfter']}/10'),
                );
              }),
          ],
        ),
      ),
    );
  }

  static Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
