import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../features/onboarding/onboarding_widgets.dart' show AuthNote;
import '../../models/doctor.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/slot_picker.dart';
import 'booking_confirmed_screen.dart';

/// Pick how, when and why — then book. Slots come live from the
/// professional's calendar for the chosen visit type and day.
class BookAppointmentScreen extends StatefulWidget {
  final Doctor doctor;
  final String? initialVisit;
  const BookAppointmentScreen({
    super.key,
    required this.doctor,
    this.initialVisit,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  late final List<String> _visits = [
    if (widget.doctor.clinicEnabled) 'clinic',
    if (widget.doctor.videoEnabled) 'video',
    if (widget.doctor.homeEnabled) 'home',
  ];
  late String _visit = _visits.contains(widget.initialVisit)
      ? widget.initialVisit!
      : (_visits.isNotEmpty ? _visits.first : 'clinic');
  DateTime? _when;
  int _reload = 0;
  final _symptoms = <String>{};
  final _reason = TextEditingController();
  final _house = TextEditingController();
  bool _booking = false;
  String? _error;

  static const _commonSymptoms = [
    'Fever',
    'Cough',
    'Cold',
    'Headache',
    'Body pain',
    'Stomach upset',
    'Skin problem',
    'Back pain',
    'Joint pain',
    'Follow-up',
  ];

  ModuleAccent get _accent =>
      widget.doctor.isPhysio ? ModuleAccent.physio : ModuleAccent.doctor;

  double get _fee => switch (_visit) {
    'video' => widget.doctor.videoCallFee,
    'home' => widget.doctor.homeVisitFee,
    _ => widget.doctor.consultationFee,
  };

  @override
  void dispose() {
    _reason.dispose();
    _house.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    if (_when == null) {
      setState(() => _error = 'Choose a time');
      return;
    }
    final location = context.read<LocationProvider>();
    if (_visit == 'home') {
      if (!location.hasPosition) {
        setState(() => _error = 'Share your location so they can find you');
        return;
      }
      if (_house.text.trim().isEmpty) {
        setState(() => _error = 'Add your house or flat number');
        return;
      }
    }
    setState(() {
      _booking = true;
      _error = null;
    });
    try {
      final address = [
        _house.text.trim(),
        location.label ?? '',
      ].where((e) => e.isNotEmpty).join(', ');
      final result = await context.read<AppointmentProvider>().book(
        professionalId: widget.doctor.id,
        professionalType: widget.doctor.professionalType,
        date: _when!,
        startTime: DateFormat('HH:mm').format(_when!),
        visit: _visit,
        symptoms: _symptoms.toList(),
        reason: _reason.text.trim(),
        address: _visit == 'home' ? address : null,
        latitude: location.lat,
        longitude: location.lng,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacement(
        AppPageRoute(
          builder: (_) => BookingConfirmedScreen(
            doctor: widget.doctor,
            result: result,
            when: _when!,
            visit: _visit,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      setState(() => _error = message);
      // The slot may have just been taken: show the day as it is now.
      if (message.toLowerCase().contains('slot') ||
          message.toLowerCase().contains('taken')) {
        setState(() => _reload++);
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doctor;
    return ModuleTheme(
      accent: _accent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(title: 'Book appointment', subtitle: d.name),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            AppEntrance(
              child: _DoctorStrip(doctor: d, accent: _accent),
            ),
            if (_visits.length > 1) ...[
              const _Step('How would you like to consult?'),
              AppEntrance(
                index: 1,
                child: Row(
                  children: [
                    for (final (i, v) in _visits.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _VisitCard(
                          visit: v,
                          fee: switch (v) {
                            'video' => d.videoCallFee,
                            'home' => d.homeVisitFee,
                            _ => d.consultationFee,
                          },
                          selected: _visit == v,
                          accent: _accent,
                          onTap: () {
                            if (_visit == v) return;
                            setState(() {
                              _visit = v;
                              _when = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const _Step('Pick a day and time'),
            AppEntrance(
              index: 2,
              child: SlotPicker(
                key: ValueKey('$_visit-$_reload'),
                professionalId: d.id,
                professionalType: d.professionalType,
                visit: _visit,
                onChanged: (at) {
                  if (_when == at) return;
                  // Reported during the picker's own build: defer.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted)
                      setState(() {
                        _when = at;
                        if (at != null) _error = null;
                      });
                  });
                },
              ),
            ),
            if (_visit == 'home') ...[
              const _Step('Where should they come?'),
              _HomeAddress(house: _house, accent: _accent),
            ],
            const _Step('What’s it about?', optional: true),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _commonSymptoms)
                  AppFilterChip(
                    label: s,
                    selected: _symptoms.contains(s),
                    onTap: () => setState(
                      () => _symptoms.contains(s)
                          ? _symptoms.remove(s)
                          : _symptoms.add(s),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: '',
              hint:
                  'Anything the ${d.isPhysio ? 'physio' : 'doctor'} should know before you meet',
              controller: _reason,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              margin: EdgeInsets.zero,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              AuthNote.error(
                _error!,
                onClose: () => setState(() => _error = null),
              ),
            ],
          ],
        ),
        bottomNavigationBar: _ConfirmBar(
          when: _when,
          fee: _fee,
          busy: _booking,
          accent: _accent,
          onConfirm: _book,
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String text;
  final bool optional;
  const _Step(this.text, {this.optional = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Row(
      children: [
        Text(
          text,
          style: AppType.sans(
            fontSize: AppType.title + 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.textStrong,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            'Optional',
            style: AppType.sans(
              fontSize: AppType.caption,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    ),
  );
}

class _DoctorStrip extends StatelessWidget {
  final Doctor doctor;
  final ModuleAccent accent;
  const _DoctorStrip({required this.doctor, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: accent.veryLight,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        AppAvatar(
          name: doctor.name,
          imageUrl: doctor.imageUrl,
          size: 46,
          radius: 14,
          color: accent.color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctor.name,
                style: AppType.sans(
                  fontSize: AppType.body + 1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textStrong,
                ),
              ),
              Text(
                [
                  doctor.specialty,
                  if (doctor.clinicName.isNotEmpty) doctor.clinicName,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sans(
                  fontSize: AppType.small,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VisitCard extends StatelessWidget {
  final String visit;
  final double fee;
  final bool selected;
  final ModuleAccent accent;
  final VoidCallback onTap;
  const _VisitCard({
    required this.visit,
    required this.fee,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (visit) {
      'video' => (LucideIcons.video, 'Video call'),
      'home' => (LucideIcons.house, 'Home visit'),
      _ => (LucideIcons.building2, 'Clinic'),
    };
    return Semantics(
      selected: selected,
      button: true,
      child: AppPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: selected ? accent.veryLight : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent.color : AppColors.borderStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? accent.color : AppColors.textSecondary,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: AppType.sans(
                  fontSize: AppType.body,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textStrong,
                ),
              ),
              Text(
                fee > 0 ? appRupees(fee) : 'Free',
                style: AppType.sans(
                  fontSize: AppType.small,
                  fontWeight: FontWeight.w600,
                  color: selected ? accent.color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAddress extends StatelessWidget {
  final TextEditingController house;
  final ModuleAccent accent;
  const _HomeAddress({required this.house, required this.accent});

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    return Column(
      children: [
        AppPressable(
          onTap: () => context.read<LocationProvider>().locate(ask: true),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: location.hasPosition
                    ? accent.color
                    : AppColors.borderStrong,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.veryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: location.locating
                      ? Padding(
                          padding: const EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent.color,
                          ),
                        )
                      : Icon(
                          LucideIcons.locateFixed,
                          size: 19,
                          color: accent.color,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.hasPosition
                            ? (location.label ?? 'Current location')
                            : 'Use my current location',
                        style: AppType.sans(
                          fontSize: AppType.body,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textStrong,
                        ),
                      ),
                      Text(
                        location.hasPosition
                            ? 'Location shared · tap to refresh'
                            : location.problem ?? 'So they can find your home',
                        style: AppType.sans(
                          fontSize: AppType.caption,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (location.hasPosition)
                  Icon(LucideIcons.circleCheck, size: 20, color: accent.color),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        AppTextField(
          label: '',
          hint: 'House / flat number, building, landmark',
          controller: house,
          icon: LucideIcons.house,
          textCapitalization: TextCapitalization.words,
          margin: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  final DateTime? when;
  final double fee;
  final bool busy;
  final ModuleAccent accent;
  final VoidCallback onConfirm;
  const _ConfirmBar({
    required this.when,
    required this.fee,
    required this.busy,
    required this.accent,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    when == null
                        ? 'No time chosen'
                        : DateFormat('EEE, d MMM · h:mm a').format(when!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(
                      fontSize: AppType.small,
                      fontWeight: FontWeight.w600,
                      color: when == null
                          ? AppColors.textTertiary
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    fee > 0 ? appRupees(fee) : 'Free',
                    style: AppType.sans(
                      fontSize: AppType.figure,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textStrong,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 170,
              child: AppButton(
                label: 'Confirm booking',
                loading: busy,
                onPressed: when == null ? null : onConfirm,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
