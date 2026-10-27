import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/app_ui.dart';
import '../../services/physio_exercise_service.dart';

ModuleAccent get _accent => ModuleAccent.physio;

/// An exercise plan from the physio: today's progress, each exercise with
/// how to do it and what to watch for, and a quick log after each set.
class PhysioExercisePlanDetailScreen extends StatefulWidget {
  final String planId;
  const PhysioExercisePlanDetailScreen({super.key, required this.planId});

  @override
  State<PhysioExercisePlanDetailScreen> createState() => _PhysioExercisePlanDetailScreenState();
}

class _PhysioExercisePlanDetailScreenState extends State<PhysioExercisePlanDetailScreen> {
  Map<String, dynamic>? _plan;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _logs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await PhysioExerciseService.instance.getPlan(widget.planId);
      if (!mounted) return;
      setState(() {
        _plan = mapOf(data['plan']);
        _summary = mapOf(data['summary']);
        _logs = mapsOf(data['progress']);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), ''));
    }
  }

  Set<String> get _doneToday {
    final now = DateTime.now();
    return {
      for (final l in _logs)
        if (DateTime.tryParse('${l['performedAt']}')?.toLocal() case final d?)
          if (d.year == now.year && d.month == now.month && d.day == now.day) (l['planItemId'] ?? '').toString(),
    };
  }

  Future<void> _log(Map<String, dynamic> item) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LogSheet(planId: widget.planId, item: item),
    );
    if (saved == true) {
      HapticFeedback.mediumImpact();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nice work — logged')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return ModuleTheme(
      accent: _accent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(title: (plan?['title'] ?? 'Exercise plan').toString()),
        body: plan == null
            ? (_error != null
                  ? Center(child: AppEmptyState(illustration: Illustrations.offline, title: 'Couldn’t load the plan', message: _error, actionLabel: 'Try again', onAction: _load))
                  : const AppDetailSkeleton())
            : RefreshIndicator(color: _accent.color, onRefresh: _load, child: _body(plan)),
      ),
    );
  }

  Widget _body(Map<String, dynamic> plan) {
    final items = mapsOf(plan['exercises']);
    final done = _doneToday;
    final doneCount = items.where((i) => done.contains(idOf(i))).length;
    final physio = mapOf(plan['physioId']);
    final active = plan['status'] == 'active';
    final painBefore = _summary['averagePainBefore'];
    final painAfter = _summary['averagePainAfter'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        AppEntrance(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _accent.veryLight, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: items.isEmpty ? 0 : doneCount / items.length),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(value: v, strokeWidth: 7, backgroundColor: Colors.white, color: _accent.color, strokeCap: StrokeCap.round),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$doneCount/${items.length}', style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
                            Text('today', style: AppType.sans(fontSize: AppType.micro, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doneCount == items.length && items.isNotEmpty ? 'All done for today' : active ? 'Today’s exercises' : PatientStatus.of(plan['status']?.toString()).label,
                        style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong),
                      ),
                      if ((physio['name'] ?? '').toString().isNotEmpty)
                        Text('From ${physio['name']}', style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Text(
                        '${_summary['completedLogs'] ?? 0} sessions logged'
                        '${painBefore != null && painAfter != null ? ' · pain $painBefore → $painAfter' : ''}',
                        style: AppType.sans(fontSize: AppType.caption, fontWeight: FontWeight.w600, color: _accent.color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if ((plan['instructions'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.messageSquareQuote, size: 17, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(child: Text(plan['instructions'].toString(), style: AppType.sans(fontSize: AppType.small, height: 1.45, color: AppColors.textPrimary))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        for (final (i, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppEntrance(
              index: i.clamp(0, 6),
              child: _ExerciseCard(
                number: i + 1,
                item: item,
                done: done.contains(idOf(item)),
                onLog: active ? () => _log(item) : null,
              ),
            ),
          ),
        if (_logs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Recent activity', style: AppType.sans(fontSize: AppType.title + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
          const SizedBox(height: 10),
          for (final l in _logs.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(LucideIcons.circleCheck, size: 17, color: _accent.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [
                        mapOf(l['exerciseId'])['name'] ?? 'Exercise',
                        '${l['setsCompleted'] ?? 0}×${l['repsCompleted'] ?? 0}',
                        if (l['painAfter'] != null) 'pain ${l['painAfter']}/10',
                      ].join(' · '),
                      style: AppType.sans(fontSize: AppType.small, color: AppColors.textPrimary),
                    ),
                  ),
                  if (DateTime.tryParse('${l['performedAt']}') != null)
                    Text(
                      DateFormat('d MMM, h:mm a').format(DateTime.parse('${l['performedAt']}').toLocal()),
                      style: AppType.sans(fontSize: AppType.caption, color: AppColors.textTertiary),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final int number;
  final Map<String, dynamic> item;
  final bool done;
  final VoidCallback? onLog;
  const _ExerciseCard({required this.number, required this.item, required this.done, required this.onLog});

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ex = mapOf(item['exerciseId']);
    final steps = (ex['instructions'] is List ? ex['instructions'] as List : const []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    final cautions = (ex['precautions'] is List ? ex['precautions'] as List : const []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    final dose = [
      if ((item['sets'] ?? 0) > 0) '${item['sets']} sets',
      if ((item['reps'] ?? 0) > 0) '${item['reps']} reps',
      if ((item['durationSec'] ?? 0) > 0) '${item['durationSec']} sec hold',
    ];
    final video = (ex['videoUrl'] ?? '').toString();
    return AnimatedContainer(
      duration: AppMotion.fast,
      decoration: BoxDecoration(
        color: widget.done ? _accent.veryLight : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.done ? _accent.light : AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: widget.done ? _accent.color : _accent.veryLight, shape: BoxShape.circle),
                    child: widget.done
                        ? const Icon(LucideIcons.check, size: 18, color: Colors.white)
                        : Text('${widget.number}', style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w800, color: _accent.color)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((ex['name'] ?? 'Exercise').toString(), style: AppType.sans(fontSize: AppType.body + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
                        Text(
                          [dose.join(' · '), item['frequency']].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
                          style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: AppMotion.fast,
                    child: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.medium,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((ex['description'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(ex['description'].toString(), style: AppType.sans(fontSize: AppType.small, height: 1.45, color: AppColors.textPrimary)),
                          ),
                        for (final (i, s) in steps.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${i + 1}.', style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w800, color: _accent.color)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(s, style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textPrimary))),
                              ],
                            ),
                          ),
                        if (cautions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(LucideIcons.triangleAlert, size: 15, color: AppColors.warning),
                                const SizedBox(width: 8),
                                Expanded(child: Text(cautions.join('\n'), style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textPrimary))),
                              ],
                            ),
                          ),
                        if ((item['notes'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('Note from your physio: ${item['notes']}', style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w600, color: _accent.color)),
                          ),
                        if (video.startsWith('http'))
                          TextButton.icon(
                            onPressed: () => launchUrl(Uri.parse(video), mode: LaunchMode.externalApplication),
                            icon: const Icon(LucideIcons.circlePlay, size: 17),
                            label: const Text('Watch how'),
                            style: TextButton.styleFrom(foregroundColor: _accent.color, padding: EdgeInsets.zero),
                          ),
                      ],
                    ),
                  ),
          ),
          if (widget.onLog != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: widget.done
                  ? AppSecondaryButton(label: 'Log again', icon: LucideIcons.plus, color: _accent.color, onPressed: widget.onLog)
                  : AppButton(label: 'I did this', icon: LucideIcons.check, compact: true, onPressed: widget.onLog),
            ),
        ],
      ),
    );
  }
}

class _LogSheet extends StatefulWidget {
  final String planId;
  final Map<String, dynamic> item;
  const _LogSheet({required this.planId, required this.item});

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  late int _sets = (widget.item['sets'] as num?)?.toInt() ?? 0;
  late int _reps = (widget.item['reps'] as num?)?.toInt() ?? 0;
  int _painBefore = 0;
  int _painAfter = 0;
  String _feel = 'about_right';
  final _notes = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PhysioExerciseService.instance.logProgress(
        widget.planId,
        planItemId: idOf(widget.item),
        setsCompleted: _sets,
        repsCompleted: _reps,
        durationSec: (widget.item['durationSec'] as num?)?.toInt() ?? 0,
        painBefore: _painBefore,
        painAfter: _painAfter,
        perceivedDifficulty: _feel,
        notes: _notes.text,
      );
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

  Widget _counter(String label, int value, ValueChanged<int> onChanged) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(label, style: AppType.sans(fontSize: AppType.caption, color: AppColors.textSecondary)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: value > 0 ? () => onChanged(value - 1) : null, icon: const Icon(LucideIcons.minus, size: 16)),
              Text('$value', style: AppType.sans(fontSize: AppType.figure, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
              IconButton(onPressed: () => onChanged(value + 1), icon: const Icon(LucideIcons.plus, size: 16)),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _pain(String label, int value, ValueChanged<int> onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const Spacer(),
          Text('$value/10', style: AppType.sans(fontSize: AppType.body, fontWeight: FontWeight.w800, color: Color.lerp(AppColors.health, AppColors.error, value / 10))),
        ],
      ),
      Slider(
        min: 0,
        max: 10,
        divisions: 10,
        value: value.toDouble(),
        activeColor: Color.lerp(AppColors.health, AppColors.error, value / 10),
        onChanged: (v) => onChanged(v.round()),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final ex = mapOf(widget.item['exerciseId']);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text((ex['name'] ?? 'Exercise').toString(), style: AppType.sans(fontSize: AppType.heading + 1, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _counter('Sets', _sets, (v) => setState(() => _sets = v)),
                  const SizedBox(width: 10),
                  _counter('Reps', _reps, (v) => setState(() => _reps = v)),
                ],
              ),
              const SizedBox(height: 14),
              _pain('Pain before', _painBefore, (v) => setState(() => _painBefore = v)),
              _pain('Pain after', _painAfter, (v) => setState(() => _painAfter = v)),
              Text('How did it feel?', style: AppType.sans(fontSize: AppType.small, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (i, (v, l)) in const [('easy', 'Easy'), ('about_right', 'About right'), ('hard', 'Hard')].indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: AppFilterChip(label: l, selected: _feel == v, block: true, onTap: () => setState(() => _feel = v))),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(label: '', hint: 'Anything to tell your physio? (optional)', controller: _notes, textCapitalization: TextCapitalization.sentences, margin: EdgeInsets.zero),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: AppType.sans(fontSize: AppType.small, color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              AppButton(label: 'Save', loading: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
