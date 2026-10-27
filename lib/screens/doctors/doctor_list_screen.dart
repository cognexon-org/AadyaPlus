import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../providers/doctor_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/doctor_card.dart';
import 'doctor_detail_screen.dart';

/// The directory of doctors (or physios): search, visit type, specialty and
/// sort, all applied on the screen so nothing leaks into other screens.
class DoctorListScreen extends StatefulWidget {
  /// 'doctor', 'physio', or null for both.
  final String? type;

  /// Start filtered to one visit type: 'clinic', 'video' or 'home'.
  final String? visit;
  final bool autofocus;
  final String? title;
  final String? specialty;
  const DoctorListScreen({
    super.key,
    this.type = 'doctor',
    this.visit,
    this.specialty,
    this.autofocus = false,
    this.title,
  });

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  late String? _visit = widget.visit;
  late String _specialty = widget.specialty ?? 'All';
  String _sort = 'rating';

  static const _sorts = {
    'rating': 'Top rated',
    'nearby': 'Nearest',
    'fee_low': 'Lowest fee',
    'experience': 'Most experienced',
  };

  ModuleAccent get _accent =>
      widget.type == 'physio' ? ModuleAccent.physio : ModuleAccent.doctor;

  String get _title =>
      widget.title ??
      (widget.type == 'physio'
          ? 'Physiotherapists'
          : widget.visit == 'video'
          ? 'Video consultation'
          : widget.type == null
          ? 'Search'
          : 'Doctors');

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  Future<void> _pickSort() async {
    final hasLocation = context.read<LocationProvider>().hasPosition;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Sort by',
                style: AppType.sans(
                  fontSize: AppType.heading,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textStrong,
                ),
              ),
            ),
            for (final e in _sorts.entries)
              ListTile(
                enabled: e.key != 'nearby' || hasLocation,
                title: Text(e.value),
                subtitle: e.key == 'nearby' && !hasLocation
                    ? const Text('Turn on location on Home to use this')
                    : null,
                trailing: _sort == e.key
                    ? Icon(LucideIcons.check, color: _accent.color, size: 20)
                    : null,
                onTap: () => Navigator.pop(context, e.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _sort = picked);
  }

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<DoctorProvider>();
    final list = directory.query(
      type: widget.type,
      visit: _visit,
      specialty: _specialty,
      search: _query,
      sort: _sort,
    );
    final specialties = ['All', ...directory.specialtiesFor(widget.type)];
    return ModuleTheme(
      accent: _accent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppTopBar(
          title: _title,
          subtitle: directory.isLoading && directory.allDoctors.isEmpty
              ? null
              : '${list.length} available',
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: TextField(
                controller: _search,
                autofocus: widget.autofocus,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                cursorColor: _accent.color,
                style: AppType.sans(fontSize: AppType.body + 1, color: AppColors.textStrong),
                decoration: InputDecoration(
                  hintText: widget.type == 'physio'
                      ? 'Search physios or conditions'
                      : 'Search name, specialty or clinic',
                  hintStyle: AppType.sans(
                    fontSize: AppType.body + 1,
                    color: AppColors.textTertiary,
                  ),
                  prefixIcon: const Icon(LucideIcons.search, size: 19, color: AppColors.textSecondary),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(LucideIcons.x, size: 17),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: AppColors.panel,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: _accent.color, width: 1.5),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Center(child: _SortChip(label: _sorts[_sort]!, onTap: _pickSort)),
                  const SizedBox(width: 8),
                  for (final v in const [null, 'clinic', 'video', 'home']) ...[
                    AppFilterChip(
                      label: switch (v) {
                        'clinic' => 'Clinic',
                        'video' => 'Video',
                        'home' => 'Home visit',
                        _ => 'Any visit',
                      },
                      selected: _visit == v,
                      onTap: () => setState(() => _visit = v),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            if (specialties.length > 2)
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  itemCount: specialties.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => AppFilterChip(
                    label: specialties[i] == 'All' ? 'All specialties' : specialties[i],
                    selected: _specialty == specialties[i],
                    onTap: () => setState(() => _specialty = specialties[i]),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Expanded(child: _body(directory, list)),
          ],
        ),
      ),
    );
  }

  Widget _body(DoctorProvider directory, List list) {
    if (directory.isLoading && directory.allDoctors.isEmpty) {
      return const AppListSkeleton(count: 5);
    }
    if (directory.error != null && directory.allDoctors.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: AppEmptyState(
            illustration: Illustrations.offline,
            title: 'Couldn’t load the directory',
            message: directory.error,
            actionLabel: 'Try again',
            onAction: directory.refreshDoctors,
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: _accent.color,
      onRefresh: directory.refreshDoctors,
      child: list.isEmpty
          ? ListView(
              children: [
                AppEmptyState(
                  illustration: Illustrations.notFound,
                  title: 'No one matches that',
                  message: 'Try another name or specialty, or clear the filters.',
                  actionLabel: 'Clear filters',
                  onAction: () {
                    _search.clear();
                    setState(() {
                      _query = '';
                      _visit = null;
                      _specialty = 'All';
                    });
                  },
                ),
              ],
            )
          : ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.of(context).padding.bottom),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => AppEntrance(
                index: i.clamp(0, 6),
                child: DoctorCard(
                  doctor: list[i],
                  onTap: () => Navigator.of(context).push(
                    AppPageRoute(builder: (_) => DoctorDetailScreen(doctorId: list[i].id)),
                  ),
                ),
              ),
            ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SortChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onTap,
    semanticLabel: 'Sort: $label',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.arrowUpDown, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppType.sans(
              fontSize: AppType.small,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}
