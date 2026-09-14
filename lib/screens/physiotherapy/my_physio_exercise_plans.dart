import 'package:flutter/material.dart';

import '../../services/physio_exercise_service.dart';
import '../../utils/constants.dart';
import 'physio_exercise_plan_detail_screen.dart';

class MyPhysioExercisePlans extends StatefulWidget {
  const MyPhysioExercisePlans({super.key});

  @override
  State<MyPhysioExercisePlans> createState() => _MyPhysioExercisePlansState();
}

class _MyPhysioExercisePlansState extends State<MyPhysioExercisePlans> {
  bool _loading = true;
  List<Map<String, dynamic>> _plans = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final plans = await PhysioExerciseService.instance.getMyPlans();
      if (mounted) setState(() => _plans = plans);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Text(_error!)),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    if (_plans.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppConstants.primaryColor.withOpacity(.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          Icon(Icons.fitness_center),
          SizedBox(width: 12),
          Expanded(child: Text('No exercise plan has been assigned yet. Your physiotherapist can create a personalized plan after consultation.')),
        ]),
      );
    }

    return SizedBox(
      height: 164,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _plans.length,
        itemBuilder: (context, index) {
          final plan = _plans[index];
          final exercises = plan['exercises'] as List? ?? const [];
          final physio = plan['physioId'] is Map
              ? Map<String, dynamic>.from(plan['physioId'])
              : <String, dynamic>{};
          return InkWell(
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PhysioExercisePlanDetailScreen(planId: plan['_id'].toString()),
              ));
              await _load();
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 230,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.primaryColor.withOpacity(.16)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppConstants.primaryColor, borderRadius: BorderRadius.circular(7)),
                  child: Text(
                    (plan['status'] ?? 'active').toString().toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  plan['title'] ?? 'Exercise plan',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('${exercises.length} exercises', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                if ((physio['name'] ?? '').toString().isNotEmpty)
                  Text('By ${physio['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
