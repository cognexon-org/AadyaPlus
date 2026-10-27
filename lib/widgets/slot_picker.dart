import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/ui/app_ui.dart';
import '../services/professional_service.dart';

/// A day strip and that day's free times, read live from a doctor's or
/// physio's calendar for one visit type. Reports the chosen start, or null
/// while none is chosen. Used by booking and rescheduling alike.
class SlotPicker extends StatefulWidget {
  final String professionalId;
  final String professionalType;
  final String visit;
  final ValueChanged<DateTime?> onChanged;
  final int days;
  const SlotPicker({
    super.key,
    required this.professionalId,
    required this.professionalType,
    required this.visit,
    required this.onChanged,
    this.days = 14,
  });

  @override
  State<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<SlotPicker> {
  late DateTime _date = _today;
  DayAvailability? _day;
  bool _loading = true;
  String? _error;
  String? _time;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requested = _date;
    setState(() {
      _loading = true;
      _error = null;
      _time = null;
    });
    widget.onChanged(null);
    try {
      final day = await ProfessionalService.instance.availability(
        id: widget.professionalId,
        type: widget.professionalType,
        date: _date,
        visit: widget.visit,
      );
      if (mounted && requested == _date) setState(() => _day = day);
    } catch (e) {
      if (mounted && requested == _date) {
        setState(() {
          _day = null;
          _error = e.toString();
        });
      }
    } finally {
      if (mounted && requested == _date) setState(() => _loading = false);
    }
  }

  void _pickDay(DateTime d) {
    if (d == _date) return;
    HapticFeedback.selectionClick();
    setState(() => _date = d);
    _load();
  }

  DateTime _at(String hhmm) {
    final p = hhmm.split(':');
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
      int.parse(p[0]),
      int.parse(p[1]),
    );
  }

  List<String> get _times {
    final now = DateTime.now();
    return (_day?.slots ?? const [])
        .map((s) => (s['startTime'] ?? '').toString())
        .where((t) => t.contains(':'))
        .where((t) => _date != _today || _at(t).isAfter(now))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ModuleAccent.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.days,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final day = _today.add(Duration(days: i));
              return _DayCard(
                date: day,
                label: i == 0
                    ? 'Today'
                    : i == 1
                    ? 'Tmrw'
                    : DateFormat('EEE').format(day),
                selected: day == _date,
                accent: accent,
                onTap: () => _pickDay(day),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: AppMotion.medium,
          alignment: Alignment.topCenter,
          child: _slots(accent),
        ),
      ],
    );
  }

  Widget _slots(ModuleAccent accent) {
    if (_loading) {
      return AppShimmer(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 8; i++)
              const AppSkeletonBlock(width: 92, height: 42, radius: 12),
          ],
        ),
      );
    }
    if (_error != null) {
      return _NoSlots(
        title: 'Couldn’t load times',
        message: _error!,
        action: 'Try again',
        onAction: _load,
      );
    }
    final times = _times;
    if (times.isEmpty) {
      final last = _date == _today.add(Duration(days: widget.days - 1));
      return _NoSlots(
        title: 'No times free on ${DateFormat('EEE, d MMM').format(_date)}',
        message: _day?.reason?.isNotEmpty == true
            ? sentenceCase(_day!.reason!)
            : 'Try another day.',
        action: last ? null : 'Next day',
        onAction: last
            ? null
            : () => _pickDay(_date.add(const Duration(days: 1))),
      );
    }
    final groups = <String, List<String>>{};
    for (final t in times) {
      final h = int.parse(t.split(':')[0]);
      groups
          .putIfAbsent(
            h < 12
                ? 'Morning'
                : h < 17
                ? 'Afternoon'
                : 'Evening',
            () => [],
          )
          .add(t);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  switch (g.key) {
                    'Morning' => LucideIcons.sunrise,
                    'Afternoon' => LucideIcons.sun,
                    _ => LucideIcons.moon,
                  },
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${g.key} · ${g.value.length} slot${g.value.length == 1 ? '' : 's'}',
                  style: AppType.sans(
                    fontSize: AppType.caption,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in g.value)
                _TimeChip(
                  label: DateFormat('h:mm a').format(_at(t)),
                  selected: _time == t,
                  accent: accent,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _time = t);
                    widget.onChanged(_at(t));
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final DateTime date;
  final String label;
  final bool selected;
  final ModuleAccent accent;
  final VoidCallback onTap;
  const _DayCard({
    required this.date,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: DateFormat('EEEE d MMMM').format(date),
    child: AppPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 58,
        decoration: BoxDecoration(
          color: selected ? accent.color : AppColors.panel,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppType.sans(
                fontSize: AppType.caption,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: AppType.sans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.textStrong,
              ),
            ),
            Text(
              DateFormat('MMM').format(date),
              style: AppType.sans(
                fontSize: AppType.micro,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ModuleAccent accent;
  final VoidCallback onTap;
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: AppPressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent.color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent.color : AppColors.borderStrong,
          ),
        ),
        child: Text(
          label,
          style: AppType.sans(
            fontSize: AppType.body,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textStrong,
          ),
        ),
      ),
    ),
  );
}

class _NoSlots extends StatelessWidget {
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  const _NoSlots({
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(
          LucideIcons.calendarX2,
          size: 22,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppType.sans(
                  fontSize: AppType.body,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textStrong,
                ),
              ),
              Text(
                message,
                style: AppType.sans(
                  fontSize: AppType.small,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: ModuleAccent.of(context).color),
            child: Text(action!),
          ),
      ],
    ),
  );
}
