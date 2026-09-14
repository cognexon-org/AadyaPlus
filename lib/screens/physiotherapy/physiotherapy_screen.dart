import 'package:flutter/material.dart';
import 'package:aadya_plus/utils/constants.dart';
import 'my_physio_exercise_plans.dart';

class PhysiotherapyScreen extends StatelessWidget {
  const PhysiotherapyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final conditions = [
      {'name': 'Back Pain', 'icon': Icons.accessibility_new, 'color': Colors.blue},
      {'name': 'Knee Pain', 'icon': Icons.directions_walk, 'color': Colors.green},
      {'name': 'Neck Pain', 'icon': Icons.airline_seat_flat, 'color': Colors.orange},
      {'name': 'Shoulder', 'icon': Icons.sports_handball, 'color': Colors.purple},
      {'name': 'Sports Injury', 'icon': Icons.sports, 'color': Colors.red},
      {'name': 'Post Surgery', 'icon': Icons.local_hospital, 'color': Colors.teal},
    ];

    final therapists = [
      {
        'name': 'Dr. Anita Desai',
        'specialization': 'Orthopedic Physiotherapy',
        'experience': '12 yrs',
        'rating': 4.8,
        'fee': 600,
        'available': true,
      },
      {
        'name': 'Dr. Rajesh Kumar',
        'specialization': 'Sports Physiotherapy',
        'experience': '8 yrs',
        'rating': 4.6,
        'fee': 500,
        'available': true,
      },
      {
        'name': 'Dr. Priya Mehta',
        'specialization': 'Neurological Physiotherapy',
        'experience': '15 yrs',
        'rating': 4.9,
        'fee': 800,
        'available': false,
      },
      {
        'name': 'Dr. Sanjay Verma',
        'specialization': 'Geriatric Physiotherapy',
        'experience': '10 yrs',
        'rating': 4.7,
        'fee': 550,
        'available': true,
      },
    ];



    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Physiotherapy',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expert Physiotherapy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Get personalized treatment plans from certified physiotherapists',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0284C7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Book Now'),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.self_improvement,
                      size: 70,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),

              // Common Conditions
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Common Conditions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: conditions.length,
                  itemBuilder: (context, index) {
                    final c = conditions[index];
                    return Container(
                      width: 90,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: (c['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              c['icon'] as IconData,
                              color: c['color'] as Color,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c['name'] as String,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Physiotherapists
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Top Physiotherapists',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'View All',
                        style: TextStyle(color: AppConstants.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...therapists.map((t) => Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppConstants.primaryColor,
                          child: Text(
                            (t['name'] as String).split(' ').last[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                t['specialization'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.star,
                                      size: 14, color: Colors.amber),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${t['rating']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.work_outline,
                                      size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${t['experience']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '₹${t['fee']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: (t['available'] as bool) ? () {} : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          child: Text(
                            (t['available'] as bool)
                                ? 'Book'
                                : 'Unavailable',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),

              // Live exercise plans assigned by the treating physiotherapist.
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'My Exercise Plans',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              const MyPhysioExercisePlans(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
