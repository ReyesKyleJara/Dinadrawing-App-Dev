import 'package:flutter/material.dart';

class MyPlansScreen extends StatefulWidget {
  const MyPlansScreen({super.key});

  @override
  State<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends State<MyPlansScreen> {
  bool _isPlansByMeExpanded = true; // Set to true by default to show the list
  bool _isPlansWithMeExpanded = true;
  bool _isDetailedView = true; // Toggle for List vs Grid(Detailed) view

  // Updated Mock Data to include images and status texts matching the Home Screen
  final List<Plan> plansByMe = [
    Plan(
      title: 'Picnic with Family',
      date: 'Apr 15',
      location: 'Kahit saang tabing ilog',
      status: 'Planned',
      statusColor: const Color(0xFFB8E4C1), // Light green
      imagePath: 'images/picnic.png', // Add these to your images folder
    ),
    Plan(
      title: 'Birthday ni Kenny',
      date: 'Apr 29',
      location: 'Boracay, Philippines',
      status: 'Plan Ongoing',
      statusColor: const Color(0xFFFFE4AD), // Light yellow
      imagePath: 'images/birthday.png',
    ),
  ];

  final List<Plan> plansWithMe = [
    Plan(
      title: 'Capstone Planning',
      date: 'Apr 10',
      location: '',
      status: 'Plan Ongoing',
      statusColor: const Color(0xFFFFE4AD),
      imagePath: 'images/capstone.png',
    ),
    Plan(
      title: 'Dinner sa Japan lang',
      date: 'Apr 8',
      location: 'Ramen House, Tokyo, Japan',
      status: 'Planned',
      statusColor: const Color(0xFFB8E4C1),
      imagePath: 'images/dinner.png',
    ),
  ];

  void _toggleExpansion(String section) {
    setState(() {
      if (section == 'plansByMe') {
        _isPlansByMeExpanded = !_isPlansByMeExpanded;
      } else if (section == 'plansWithMe') {
        _isPlansWithMeExpanded = !_isPlansWithMeExpanded;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFF2B73F),
        shape: const CircleBorder(),
        elevation: 0,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // 24px margin to match Home Screen perfectly
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Active Plans',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  _buildFilterBar(),
                ],
              ),
              const SizedBox(height: 16),

              _buildExpansionSection('Plans by Me', plansByMe, _isPlansByMeExpanded, 'plansByMe'),
              const SizedBox(height: 16),
              _buildExpansionSection('Plans with Me', plansWithMe, _isPlansWithMeExpanded, 'plansWithMe'),

              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Plans',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage, view, and edit your plans easily.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const CircleAvatar(
          radius: 25,
          backgroundImage: AssetImage('images/user-avatar.png'),
          backgroundColor: Colors.transparent,
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        Icon(Icons.sort, size: 22, color: Colors.grey[600]),
        const SizedBox(width: 12),
        // Toggle to Detailed/Grid View
        GestureDetector(
          onTap: () => setState(() => _isDetailedView = false),
          child: Icon(
            Icons.view_headline,
            size: 24,
            color: !_isDetailedView ? Colors.blue : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 12),
        // Toggle to List View
        GestureDetector(
          onTap: () => setState(() => _isDetailedView = true),
          child: Icon(
            Icons.grid_view,
            size: 22,
            color: _isDetailedView ? Colors.blue : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.more_vert, size: 22, color: Colors.grey[600]),
      ],
    );
  }

  Widget _buildExpansionSection(String title, List<Plan> plans, bool isExpanded, String sectionId) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _toggleExpansion(sectionId),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                color: Colors.grey[800],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: plans.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _isDetailedView 
                ? _buildDetailedPlanCard(plans[index]) 
                : _buildCompactPlanCard(plans[index]),
          ),
        ]
      ],
    );
  }

  // Matches the new screenshot exactly
  Widget _buildDetailedPlanCard(Plan plan) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 80,
              height: 100,
              color: Colors.grey.shade200, // Background color while loading
              child: Image.asset(
                plan.imagePath,
                fit: BoxFit.cover,
                // Fallback icon if image is missing so app doesn't crash
                errorBuilder: (context, error, stackTrace) => 
                    Icon(Icons.image_outlined, color: Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right Side Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.date}${plan.location.isEmpty ? '' : ' • ${plan.location}'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Mock Avatars (Matching Home Screen)
                    const SizedBox(
                      width: 80,
                      child: Stack(
                        children: [
                          CircleAvatar(radius: 12, backgroundColor: Colors.grey),
                          Positioned(left: 15, child: CircleAvatar(radius: 12, backgroundColor: Colors.blueGrey)),
                          Positioned(left: 30, child: CircleAvatar(radius: 12, backgroundColor: Colors.amber)),
                          Positioned(
                            left: 45, 
                            child: CircleAvatar(
                              radius: 12, 
                              backgroundColor: Color(0xFFE0E0E0),
                              child: Text('+3', style: TextStyle(fontSize: 9, color: Colors.black)),
                            )
                          ),
                        ],
                      ),
                    ),
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: plan.statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        plan.status,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Simple compact view (when clicking the list icon)
  Widget _buildCompactPlanCard(Plan plan) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.date}${plan.location.isEmpty ? '' : ' • ${plan.location}'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: plan.statusColor, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

class Plan {
  final String title;
  final String date;
  final String location;
  final String status;
  final Color statusColor;
  final String imagePath;

  Plan({
    required this.title,
    required this.date,
    required this.location,
    required this.status,
    required this.statusColor,
    required this.imagePath,
  });
}