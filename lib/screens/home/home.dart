import 'dart:async';

import 'package:flutter/material.dart';
import '../../navigation/main_wrapper.dart';
import '../../tab/quick_decision.dart';
import '../settings/settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showWheel = true;
  Timer? _switchTimer;

  @override
  void initState() {
    super.initState();
    _switchTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _showWheel = !_showWheel);
    });
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, User!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'What are we planning today?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  ClipOval(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MainWrapper(initialIndex: 3))),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          ProfileService.instance.avatarBytes,
                          ProfileService.instance.avatarIcon,
                        ]),
                        builder: (context, _) {
                          final bytes = ProfileService.instance.avatarBytes.value;
                          final icon = ProfileService.instance.avatarIcon.value;

                          if (bytes != null) {
                            return CircleAvatar(radius: 19, backgroundImage: MemoryImage(bytes));
                          }
                          if (icon != null) {
                            return CircleAvatar(radius: 19, backgroundColor: Colors.grey[300], child: Icon(icon, size: 16, color: Colors.black));
                          }

                          return const CircleAvatar(
                            radius: 19,
                            backgroundColor: Color(0xFFE0E0E0),
                            child: Icon(Icons.person, color: Colors.grey, size: 16),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Decision Card (Spin the Wheel / Blitz Poll)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Can\'t decide where to go?',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Use spin the wheel or blitz poll for quick decisions',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const QuickDecisionPage(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF2B73F),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Try it now', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    // Animated images switching between wheel and blitz poll
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                      child: _showWheel
                          ? Image.asset('images/wheel.png', key: const ValueKey('wheel'), width: 80, height: 80)
                          : Image.asset('images/page3.png', key: const ValueKey('blitz'), width: 80, height: 80),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Upcoming Plans Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upcoming Plans',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MainWrapper(initialIndex: 1),
                        ),
                      );
                    },
                    child: Text(
                      'View all >',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Plans List
              const PlanCard(
                title: 'Dinner sa Japan lang',
                date: 'Apr 8',
                location: 'Ramen House, Tokyo, Japan',
                status: 'Planned',
                statusColor: Color(0xFFB8E4C1),
              ),
              const PlanCard(
                title: 'Picnic with Family',
                date: 'Apr 15',
                location: 'Kahit saang tabing ilog',
                status: 'Planned',
                statusColor: Color(0xFFB8E4C1),
              ),
              const PlanCard(
                title: 'Birthday ni Kenny',
                date: 'Apr 29',
                location: 'Boracay, Philippines',
                status: 'Plan Ongoing',
                statusColor: Color(0xFFFFE4AD),
              ),
              const SizedBox(height: 100), // Space for FAB
            ],
          ),
        ),
      ),
    );
  }
}

class PlanCard extends StatelessWidget {
  final String title;
  final String date;
  final String location;
  final String status;
  final Color statusColor;

  const PlanCard({
    super.key,
    required this.title,
    required this.date,
    required this.location,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$date • $location', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Mock Avatars
              const SizedBox(
                width: 100,
                child: Stack(
                  children: [
                    CircleAvatar(radius: 12, backgroundColor: Colors.grey),
                    Positioned(left: 15, child: CircleAvatar(radius: 12, backgroundColor: Colors.blueGrey)),
                    Positioned(left: 30, child: CircleAvatar(radius: 12, backgroundColor: Colors.amber)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}