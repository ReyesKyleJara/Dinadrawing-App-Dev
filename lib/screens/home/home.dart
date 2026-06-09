import 'dart:async';

import 'package:flutter/material.dart';
import '../../navigation/main_wrapper.dart';
import '../../tab/quick_decision.dart';
import '../settings/settings.dart';
import '../../services/auth_service.dart';
import '../../services/plan_service.dart';
import '../myplans/plan_model.dart';
import '../plans/plan_dashboard/plan_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showWheel = true;
  Timer? _switchTimer;
  String _userName = 'User';

  bool _isLoadingPlans = true;
  List<Plan> _upcomingPlans = [];

  @override
  void initState() {
    super.initState();

    _loadCurrentUser();
    _loadUpcomingPlans();

    _switchTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _showWheel = !_showWheel);
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.getCurrentUser();

      if (!mounted) return;

      if (user != null && user['name'] != null) {
        setState(() {
          _userName = user['name'];
        });
      }
    } catch (e) {
      print('HOME USER LOAD ERROR: $e');
    }
  }

  Future<void> _loadUpcomingPlans() async {
    setState(() {
      _isLoadingPlans = true;
    });

    try {
      final result = await PlanService.getPlans();

      final plansByMeData = result['plans_by_me'];
      final plansWithMeData = result['plans_with_me'];

      final plansByMe = plansByMeData is List
          ? plansByMeData
              .map((item) => Plan.fromJson(item as Map<String, dynamic>))
              .toList()
          : <Plan>[];

      final plansWithMe = plansWithMeData is List
          ? plansWithMeData
              .map((item) => Plan.fromJson(item as Map<String, dynamic>))
              .toList()
          : <Plan>[];

      final combinedPlans = [...plansByMe, ...plansWithMe];

      if (!mounted) return;

      setState(() {
        _upcomingPlans = combinedPlans.take(3).toList();
        _isLoadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingPlans = false;
      });

      print('HOME PLANS LOAD ERROR: $e');
    }
  }

  void _openPlanDashboard(Plan plan) {
    if (plan.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open plan. Missing plan ID.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanDashboardScreen(
          planId: plan.id!,
        ),
      ),
    );
  }

  String _getPlanDateLocationText(Plan plan) {
    final hasDate = plan.date.trim().isNotEmpty;
    final hasLocation = plan.location.trim().isNotEmpty;

    if (hasDate && hasLocation) {
      return '${plan.date} • ${plan.location}';
    }

    if (hasDate) {
      return plan.date;
    }

    if (hasLocation) {
      return plan.location;
    }

    return 'No date or location yet';
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
      body: RefreshIndicator(
        color: const Color(0xFFF2B73F),
        onRefresh: _loadUpcomingPlans,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),

                const SizedBox(height: 24),

                _buildQuickDecisionCard(),

                const SizedBox(height: 32),

                _buildUpcomingPlansHeader(),

                const SizedBox(height: 12),

                if (_isLoadingPlans)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(
                        color: Color(0xFFF2B73F),
                      ),
                    ),
                  )
                else if (_upcomingPlans.isEmpty)
                  _buildEmptyPlansState()
                else
                  ..._upcomingPlans.map(
                    (plan) => HomePlanCard(
                      plan: plan,
                      dateLocationText: _getPlanDateLocationText(plan),
                      onTap: () => _openPlanDashboard(plan),
                    ),
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $_userName!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'What are we planning today?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        ClipOval(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MainWrapper(initialIndex: 3),
              ),
            ),
            child: AnimatedBuilder(
              animation: Listenable.merge([
                ProfileService.instance.avatarBytes,
                ProfileService.instance.avatarIcon,
              ]),
              builder: (context, _) {
                final bytes = ProfileService.instance.avatarBytes.value;
                final icon = ProfileService.instance.avatarIcon.value;

                if (bytes != null) {
                  return CircleAvatar(
                    radius: 19,
                    backgroundImage: MemoryImage(bytes),
                  );
                }

                if (icon != null) {
                  return CircleAvatar(
                    radius: 19,
                    backgroundColor: Colors.grey[300],
                    child: Icon(
                      icon,
                      size: 16,
                      color: Colors.black,
                    ),
                  );
                }

                return const CircleAvatar(
                  radius: 19,
                  backgroundColor: Color(0xFFE0E0E0),
                  child: Icon(
                    Icons.person,
                    color: Colors.grey,
                    size: 16,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickDecisionCard() {
    return Container(
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Use spin the wheel or blitz poll for quick decisions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
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
                  child: const Text(
                    'Try it now',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: _showWheel
                ? Image.asset(
                    'images/wheel.png',
                    key: const ValueKey('wheel'),
                    width: 80,
                    height: 80,
                  )
                : Image.asset(
                    'images/blitz.png',
                    key: const ValueKey('blitz'),
                    width: 80,
                    height: 80,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingPlansHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Upcoming Plans',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
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
    );
  }

  Widget _buildEmptyPlansState() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFAEF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFFFFE4AD),
        width: 1,
      ),
    ),
    child: Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFF2B73F).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.event_note_outlined,
            size: 34,
            color: Color(0xFFF2B73F),
          ),
        ),

        const SizedBox(height: 14),

        const Text(
          'No plans yet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Create your first plan or join one using an invite code.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MainWrapper(initialIndex: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2B73F),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Create Plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MainWrapper(initialIndex: 1),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(
                    color: Color(0xFFF2B73F),
                    width: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Join Plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
}

class HomePlanCard extends StatelessWidget {
  final Plan plan;
  final String dateLocationText;
  final VoidCallback onTap;

  const HomePlanCard({
    super.key,
    required this.plan,
    required this.dateLocationText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bannerColor = Plan.parseColor(plan.bannerColor);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 8,
                decoration: BoxDecoration(
                  color: bannerColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLocationText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(
                            width: 72,
                            height: 24,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(0xFFE0E0E0),
                                  child: Icon(
                                    Icons.person,
                                    size: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                                Positioned(
                                  left: 15,
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Color(0xFFD8D8D8),
                                    child: Icon(
                                      Icons.person,
                                      size: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 30,
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Color(0xFFCFCFCF),
                                    child: Icon(
                                      Icons.person,
                                      size: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: plan.statusColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              plan.status,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}