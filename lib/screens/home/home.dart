import 'dart:async';

import 'package:flutter/material.dart';

import '../../navigation/main_wrapper.dart';
import '../../services/auth_service.dart';
import '../../services/plan_service.dart';
import '../../services/profile_service.dart';
import '../quick_decision/quick_decision.dart';
import '../myplans/plan_model.dart';
import '../plans/create_plan.dart';
import '../plans/join_plan.dart';
import '../plans/plan_dashboard/plan_dashboard.dart';

const Color _brandYellow = Color(0xFFF2B73F);
const Color _brandYellowDark = Color(0xFFD89B22);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showWheel = true;
  bool _isLoadingPlans = true;

  Timer? _switchTimer;

  List<Plan> _upcomingPlans = [];

  @override
  void initState() {
    super.initState();

    _loadCurrentUser();
    _loadUpcomingPlans();

    _switchTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _showWheel = !_showWheel;
        });
      },
    );
  }

  @override
  void dispose() {
    _switchTimer?.cancel();

    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final settingsResult =
          await AuthService.getUserSettings();

      Map<String, dynamic>? user;

      final rawUser = settingsResult['user'];

      if (rawUser is Map) {
        user = Map<String, dynamic>.from(
          rawUser,
        );
      }

      user ??= await AuthService.getCurrentUser();

      if (user == null) {
        return;
      }

      ProfileService.instance.syncFromUser(
        user,
        clearAvatarWhenMissing: true,
      );
    } catch (error) {
      debugPrint(
        'HOME USER LOAD ERROR: $error',
      );
    }
  }

  Future<void> _loadUpcomingPlans() async {
    if (mounted) {
      setState(() {
        _isLoadingPlans = true;
      });
    }

    try {
      final result = await PlanService.getPlans();

      final plansByMe = _parsePlans(
        result['plans_by_me'],
      );

      final plansWithMe = _parsePlans(
        result['plans_with_me'],
      );

      final combinedPlans = [
        ...plansByMe,
        ...plansWithMe,
      ];

      if (!mounted) {
        return;
      }

      setState(() {
        _upcomingPlans = combinedPlans.take(3).toList();
        _isLoadingPlans = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPlans = false;
      });

      debugPrint(
        'HOME PLANS LOAD ERROR: $error',
      );
    }
  }

  List<Plan> _parsePlans(dynamic rawPlans) {
    if (rawPlans is! List) {
      return [];
    }

    return rawPlans
        .whereType<Map>()
        .map(
          (item) => Plan.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> _refreshHome() async {
    await Future.wait([
      _loadCurrentUser(),
      _loadUpcomingPlans(),
    ]);
  }

  Future<void> _openCreatePlan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreatePlanPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadUpcomingPlans();
  }

  Future<void> _openJoinPlan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const JoinPlanPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadUpcomingPlans();
  }

  void _openPlanDashboard(Plan plan) {
    if (plan.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open plan. Missing plan ID.',
          ),
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
    ).then((_) {
      _loadUpcomingPlans();
    });
  }

  String _getPlanDateLocationText(
    Plan plan,
  ) {
    final hasDate = plan.date.trim().isNotEmpty;
    final hasLocation =
        plan.location.trim().isNotEmpty;

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: _brandYellow,
        onRefresh: _refreshHome,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
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
                      padding: EdgeInsets.symmetric(
                        vertical: 40,
                      ),
                      child: CircularProgressIndicator(
                        color: _brandYellow,
                      ),
                    ),
                  )
                else if (_upcomingPlans.isEmpty)
                  _buildEmptyPlansState()
                else
                  ..._upcomingPlans.map(
                    (plan) {
                      return HomePlanCard(
                        plan: plan,
                        dateLocationText:
                            _getPlanDateLocationText(
                          plan,
                        ),
                        onTap: () {
                          _openPlanDashboard(plan);
                        },
                      );
                    },
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<String>(
                valueListenable:
                    ProfileService.instance.name,
                builder: (
                  context,
                  profileName,
                  child,
                ) {
                  final displayName =
                      profileName.trim().isEmpty
                          ? 'User'
                          : profileName.trim();

                  return Text(
                    'Hello, $displayName!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                      height: 1.05,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                'What are we planning today?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MainWrapper(
                  initialIndex: 3,
                ),
              ),
            );
          },
          child: const ProfileAvatar(
            radius: 19,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickDecisionCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark =
        theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: 0.65,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.20 : 0.05,
            ),
            blurRadius: 12,
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
                Text(
                  'Can\'t decide where to go?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Use spin the wheel or blitz poll for quick decisions.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const QuickDecisionPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandYellow,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Try it now',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(
              milliseconds: 500,
            ),
            transitionBuilder: (
              child,
              animation,
            ) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: _showWheel
                ? Image.asset(
                    'images/wheel.png',
                    key: const ValueKey('wheel'),
                    width: 82,
                    height: 82,
                  )
                : Image.asset(
                    'images/blitz.png',
                    key: const ValueKey('blitz'),
                    width: 82,
                    height: 82,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingPlansHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Upcoming Plans',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MainWrapper(
                  initialIndex: 1,
                ),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View all',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPlansState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark =
        theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        22,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? _brandYellow.withValues(
                alpha: 0.08,
              )
            : const Color(0xFFFFFAEF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? _brandYellow.withValues(
                  alpha: 0.30,
                )
              : const Color(0xFFFFE4AD),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _brandYellow.withValues(
                alpha: isDark ? 0.22 : 0.18,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.event_note_outlined,
              size: 34,
              color: _brandYellow,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No plans yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create your first plan or join one using an invite code.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: colors.onSurfaceVariant,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _openCreatePlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandYellow,
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
                  onPressed: _openJoinPlan,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onSurface,
                    minimumSize: const Size(0, 44),
                    side: const BorderSide(
                      color: _brandYellow,
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
  const HomePlanCard({
    super.key,
    required this.plan,
    required this.dateLocationText,
    required this.onTap,
  });

  final Plan plan;
  final String dateLocationText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark =
        theme.brightness == Brightness.dark;

    final bannerColor =
        Plan.parseColor(plan.bannerColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(
            bottom: 14,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(
              color: colors.outlineVariant.withValues(
                alpha: 0.72,
              ),
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDark ? 0.18 : 0.035,
                ),
                blurRadius: 9,
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
                    borderRadius:
                        const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      14,
                      14,
                      14,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              theme.textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateLocationText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _PlanMemberAvatarStack(
                              surfaceColor: colors.surface,
                              avatarBackground: colors
                                  .surfaceContainerHighest,
                              iconColor:
                                  colors.onSurfaceVariant,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: plan.statusColor,
                                borderRadius:
                                    BorderRadius.circular(20),
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
      ),
    );
  }
}

class _PlanMemberAvatarStack extends StatelessWidget {
  const _PlanMemberAvatarStack({
    required this.surfaceColor,
    required this.avatarBackground,
    required this.iconColor,
  });

  final Color surfaceColor;
  final Color avatarBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 24,
      child: Stack(
        children: [
          _buildAvatar(
            left: 0,
            backgroundColor: avatarBackground,
          ),
          _buildAvatar(
            left: 15,
            backgroundColor: avatarBackground.withValues(
              alpha: 0.92,
            ),
          ),
          _buildAvatar(
            left: 30,
            backgroundColor: avatarBackground.withValues(
              alpha: 0.84,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required double left,
    required Color backgroundColor,
  }) {
    return Positioned(
      left: left,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: surfaceColor,
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: 12,
          backgroundColor: backgroundColor,
          child: Icon(
            Icons.person_rounded,
            size: 13,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}