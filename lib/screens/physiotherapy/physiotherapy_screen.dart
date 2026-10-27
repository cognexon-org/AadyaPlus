import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../providers/doctor_provider.dart';
import '../../services/physio_exercise_service.dart';
import '../../widgets/doctor_card.dart';
import '../doctors/doctor_detail_screen.dart';
import '../doctors/doctor_list_screen.dart';
import 'physio_exercise_plan_detail_screen.dart';

/// Physiotherapy: the patient's own care first (exercise plans and
/// treatment courses their physio set up), then finding a physio.
class PhysiotherapyScreen extends StatefulWidget {
  const PhysiotherapyScreen({super.key});

  @override
  State<PhysiotherapyScreen> createState() => _PhysiotherapyScreenState();
}

class _PhysiotherapyScreenState extends State<PhysiotherapyScreen> {
  List<Map<String, dynamic>>? _plans;
  List<Map<String, dynamic>>? _courses;
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
        PhysioExerciseService.instance.getMyPlans(),
        PhysioExerciseService.instance.getMyCourses().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = results[0];
        _courses = results[1];
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _plans ??= [];
          _courses ??= [];
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _push(Widget w) => Navigator.of(context).push(AppPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<DoctorProvider>();
    final physios = directory.query(type: 'physio').take(5).toList();
    final specialties = directory.specialtiesFor('physio').take(8).toList();
    final activePlans = (_plans ?? const []).where((p) => p['status'] != 'cancelled').toList();
    final activeCourses = (_courses ?? const []).where((c) => c['status'] == 'active').toList();
    return ModuleTheme(
      accent: ModuleAccent.physio,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: const AppTopBar(title: 'Physiotherapy'),
        body: RefreshIndicator(
          color: ModuleAccent.physio.color,
          onRefresh: () => Future.wait([_load(), directory.refreshDoctors()]),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: AppEntrance(
                  child: _Hero(onFind: () => _push(const DoctorListScreen(type: 'physio'))),
                ),
              ),
              if (_plans == null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: AppShimmer(child: AppSkeletonBlock(width: double.infinity, height: 110, radius: 18)),
                )
              else ...[
                if (activeCourses.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  const AppSectionHeader(title: 'Your treatment'),
                  for (final c in activeCourses)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _CourseCard(course: c),
                    ),
                ],
                const SizedBox(height: 26),
                const AppSectionHeader(title: 'Exercise plans'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AppErrorBanner(message: _error!, onRetry: _load),
                  )
                else if (activePlans.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _NoPlans(),
                  )
                else
                  for (final p in activePlans)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _PlanCard(
                        plan: p,
                        onTap: () async {
                          await Navigator.of(context).push(
                            AppPageRoute(builder: (_) => PhysioExercisePlanDetailScreen(planId: idOf(p))),
                          );
                          _load();
                        },
                      ),
                    ),
              ],
              if (specialties.isNotEmpty) ...[
                const SizedBox(height: 26),
                const AppSectionHeader(title: 'Find help for'),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: specialties.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => AppFilterChip(
                      label: specialties[i],
                      selected: false,
                      onTap: () => _push(DoctorListScreen(type: 'physio', specialty: specialties[i])),
                    ),
                  ),
                ),
              ],
              if (physios.isNotEmpty) ...[
                const SizedBox(height: 26),
                AppSectionHeader(
                  title: 'Physiotherapists',
                  action: 'See all',
                  onAction: () => _push(const DoctorListScreen(type: 'physio')),
                ),
                for (final (i, d) in physios.indexed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: AppEntrance(
                      index: i,
                      child: DoctorCard(doctor: d, onTap: () => _push(DoctorDetailScreen(doctorId: d.id))),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final VoidCallback onFind;
  const _Hero({required this.onFind});

  @override
  Widget build(BuildContext context) {
    final accent = ModuleAccent.physio;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 8, 18),
      decoration: BoxDecoration(
        color: accent.veryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.light),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recover with an expert',
                  style: AppType.sans(
                    fontSize: AppType.title + 2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textStrong,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sessions at home or at the clinic, with exercises you can follow every day.',
                  style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                AppButton(label: 'Find a physio', icon: LucideIcons.search, onPressed: onFind, fullWidth: false, compact: true),
              ],
            ),
          ),
          const AppIllustration(Illustrations.exercise, height: 104, float: true),
        ],
      ),
    );
  }
}

class _NoPlans extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.dumbbell, size: 22, color: ModuleAccent.physio.color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'No plans yet. After your first session your physio can set exercises for you here.',
            style: AppType.sans(fontSize: AppType.small, height: 1.4, color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onTap;
  const _PlanCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = ModuleAccent.physio;
    final exercises = mapsOf(plan['exercises']);
    final physio = mapOf(plan['physioId']);
    final status = PatientStatus.of(plan['status']?.toString() == 'active' ? 'in_progress' : plan['status']?.toString());
    return AppPressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: accent.veryLight, borderRadius: BorderRadius.circular(14)),
              child: Icon(LucideIcons.dumbbell, size: 22, color: accent.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (plan['title'] ?? 'Exercise plan').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(
                      fontSize: AppType.body + 1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textStrong,
                    ),
                  ),
                  Text(
                    [
                      '${exercises.length} exercise${exercises.length == 1 ? '' : 's'}',
                      if ((physio['name'] ?? '').toString().isNotEmpty) physio['name'],
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  status.pill(),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final accent = ModuleAccent.physio;
    final total = ((course['totalSessions'] ?? 0) as num).toInt();
    final used = ((course['sessionsUsed'] ?? 0) as num).toInt();
    final physio = mapOf(course['physioId']);
    final goals = (course['goals'] is List ? course['goals'] as List : const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (course['title'] ?? 'Treatment course').toString(),
                  style: AppType.sans(
                    fontSize: AppType.body + 1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
              Text(
                '$used of $total sessions',
                style: AppType.sans(
                  fontSize: AppType.small,
                  fontWeight: FontWeight.w700,
                  color: accent.color,
                ),
              ),
            ],
          ),
          if ((physio['name'] ?? '').toString().isNotEmpty)
            Text(
              'With ${physio['name']}',
              style: AppType.sans(fontSize: AppType.small, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: total == 0 ? 0 : used / total),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: accent.veryLight,
                color: accent.color,
              ),
            ),
          ),
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final g in goals.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(LucideIcons.target, size: 13, color: accent.color),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(g, style: AppType.sans(fontSize: AppType.small, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
