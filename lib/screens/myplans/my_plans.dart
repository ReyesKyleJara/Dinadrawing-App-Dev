import 'package:flutter/material.dart';

import '../../navigation/main_wrapper.dart';
import '../../services/auth_service.dart';
import '../../services/plan_service.dart';
import '../../services/profile_service.dart';
import '../plans/plan_dashboard/plan_dashboard.dart';
import 'archived_plans.dart';
import 'deleted_plans.dart';
import 'plan_model.dart';

const Color _brandYellow = Color(0xFFF2B73F);
const Color _brandYellowDark = Color(0xFFD89B22);

class MyPlansScreen extends StatefulWidget {
  const MyPlansScreen({super.key});

  @override
  State<MyPlansScreen> createState() {
    return _MyPlansScreenState();
  }
}

class _MyPlansScreenState extends State<MyPlansScreen> {
  bool _isPlansByMeExpanded = true;
  bool _isPlansWithMeExpanded = true;
  bool _isDetailedView = true;
  bool _isLoadingPlans = true;
  bool _isProcessingAction = false;

  int? _currentUserId;

  List<Plan> _plansByMe = [];
  List<Plan> _plansWithMe = [];

  @override
  void initState() {
    super.initState();

    _loadPlans();
  }

  Future<void> _loadPlans() async {
    if (mounted) {
      setState(() {
        _isLoadingPlans = true;
      });
    }

    try {
      final settingsResult = await AuthService.getUserSettings();

      Map<String, dynamic>? currentUser;

      final rawUser = settingsResult['user'];

      if (rawUser is Map) {
        currentUser = Map<String, dynamic>.from(rawUser);
      }

      currentUser ??= await AuthService.getCurrentUser();

      if (currentUser != null) {
        ProfileService.instance.syncFromUser(currentUser);
      }

      final result = await PlanService.getPlans();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUserId = _parseInt(currentUser?['id']);

        _plansByMe = _parsePlans(result['plans_by_me']);

        _plansWithMe = _parsePlans(result['plans_with_me']);

        _isLoadingPlans = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPlans = false;
      });

      _showSnackBar('Failed to load plans: $error', isError: true);
    }
  }

  List<Plan> _parsePlans(dynamic raw) {
    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Plan.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  bool _isAdmin(Plan plan) {
    return _currentUserId != null && plan.adminId == _currentUserId;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
      ),
    );
  }

  void _openPlanDashboard(Plan plan) {
    if (plan.id == null) {
      _showSnackBar('Unable to open plan. Missing plan ID.', isError: true);

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlanDashboardScreen(planId: plan.id!)),
    ).then((_) {
      _loadPlans();
    });
  }

  void _toggleExpansion(String section) {
    setState(() {
      if (section == 'plansByMe') {
        _isPlansByMeExpanded = !_isPlansByMeExpanded;
      } else if (section == 'plansWithMe') {
        _isPlansWithMeExpanded = !_isPlansWithMeExpanded;
      }
    });
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
    required bool destructive,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: destructive
                  ? colors.errorContainer
                  : _brandYellow.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              destructive
                  ? Icons.delete_outline_rounded
                  : Icons.archive_outlined,
              color: destructive ? colors.onErrorContainer : _brandYellowDark,
              size: 25,
            ),
          ),
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            content,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: destructive ? Colors.white : Colors.black,
                elevation: 0,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runPlanAction(Future<void> Function() action) async {
    if (_isProcessingAction) {
      return;
    }

    setState(() {
      _isProcessingAction = true;
    });

    try {
      await action();
      await _loadPlans();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _archivePlan(Plan plan) async {
    if (!_isAdmin(plan)) {
      _showSnackBar(
        'Only the plan admin can archive this plan.',
        isError: true,
      );

      return;
    }

    if (plan.id == null) {
      _showSnackBar('Unable to archive plan. Missing plan ID.', isError: true);

      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Archive Plan',
      content: 'Archive "${plan.title}"? You can restore it later.',
      confirmText: 'Archive',
      confirmColor: _brandYellow,
      destructive: false,
    );

    if (confirmed != true) {
      return;
    }

    await _runPlanAction(() async {
      final result = await PlanService.archivePlan(plan.id!);

      _showSnackBar(result['message']?.toString() ?? '${plan.title} archived.');
    });
  }

  Future<void> _deletePlan(Plan plan) async {
    if (!_isAdmin(plan)) {
      _showSnackBar('Only the plan admin can delete this plan.', isError: true);

      return;
    }

    if (plan.id == null) {
      _showSnackBar('Unable to delete plan. Missing plan ID.', isError: true);

      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Delete Plan',
      content: 'Move "${plan.title}" to Deleted Plans?',
      confirmText: 'Delete',
      confirmColor: Colors.red.shade500,
      destructive: true,
    );

    if (confirmed != true) {
      return;
    }

    await _runPlanAction(() async {
      final result = await PlanService.deletePlan(plan.id!);

      if (result['success'] == false) {
        _showSnackBar(
          result['message']?.toString() ?? 'Failed to delete plan.',
          isError: true,
        );

        return;
      }

      _showSnackBar(
        result['message']?.toString() ??
            '${plan.title} moved to Deleted Plans.',
      );
    });
  }

  void _openArchivePlansPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArchivedPlansPage()),
    ).then((_) {
      _loadPlans();
    });
  }

  void _openDeletedPlansPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeletedPlansPage()),
    ).then((_) {
      _loadPlans();
    });
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: _brandYellow,
        onRefresh: _loadPlans,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Plans',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: colors.onSurface,
                        height: 1.1,
                      ),
                    ),
                    _buildFilterBar(),
                  ],
                ),
                const SizedBox(height: 20),
                if (_isLoadingPlans)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: CircularProgressIndicator(color: _brandYellow),
                    ),
                  )
                else ...[
                  _buildExpansionSection(
                    'Plans by Me',
                    _plansByMe,
                    _isPlansByMeExpanded,
                    'plansByMe',
                  ),
                  const SizedBox(height: 18),
                  _buildExpansionSection(
                    'Plans with Me',
                    _plansWithMe,
                    _isPlansWithMeExpanded,
                    'plansWithMe',
                  ),
                  const SizedBox(height: 90),
                ],
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
              Text(
                'My Plans',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage, view, and edit your plans easily.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurfaceVariant,
                  height: 1.2,
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
                builder: (_) => const MainWrapper(initialIndex: 3),
              ),
            );
          },
          child: const ProfileAvatar(radius: 19),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.70),
        ),
      ),
      child: Row(
        children: [
          _buildViewButton(
            assetPath: 'images/list.png',
            selected: !_isDetailedView,
            tooltip: 'List view',
            onTap: () {
              setState(() {
                _isDetailedView = false;
              });
            },
          ),
          const SizedBox(width: 4),
          _buildViewButton(
            assetPath: 'images/grid.png',
            selected: _isDetailedView,
            tooltip: 'Detailed view',
            onTap: () {
              setState(() {
                _isDetailedView = true;
              });
            },
          ),
          const SizedBox(width: 2),
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: Icon(
              Icons.more_vert_rounded,
              size: 21,
              color: colors.onSurface,
            ),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: colors.surface,
            offset: const Offset(0, 42),
            elevation: 8,
            onSelected: (value) {
              if (value == 'archive') {
                _openArchivePlansPage();
              } else if (value == 'delete') {
                _openDeletedPlansPage();
              }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  value: 'archive',
                  child: _buildPopupItem(
                    icon: Icons.archive_outlined,
                    label: 'Archived Plans',
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: _buildPopupItem(
                    icon: Icons.delete_outline_rounded,
                    label: 'Deleted Plans',
                    destructive: true,
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton({
    required String assetPath,
    required bool selected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? colors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 31,
            height: 31,
            child: Center(
              child: Image.asset(
                assetPath,
                width: 17,
                height: 17,
                color: selected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    selected
                        ? Icons.grid_view_rounded
                        : Icons.view_list_rounded,
                    size: 18,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupItem({
    required IconData icon,
    required String label,
    bool destructive = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final foreground = destructive ? colors.error : colors.onSurface;

    return Row(
      children: [
        Icon(icon, size: 19, color: foreground),
        const SizedBox(width: 11),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: foreground,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildExpansionSection(
    String title,
    List<Plan> plans,
    bool isExpanded,
    String sectionId,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _toggleExpansion(sectionId);
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: isExpanded ? 0 : -0.25,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.onSurface,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 28),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      plans.length.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: !isExpanded
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: plans.isEmpty
                      ? _buildSmallEmptySection(title)
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: plans.length,
                          separatorBuilder: (context, index) {
                            return const SizedBox(height: 10);
                          },
                          itemBuilder: (context, index) {
                            final plan = plans[index];

                            return _isDetailedView
                                ? _buildDetailedPlanCard(plan)
                                : _buildListPlanCard(plan);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildSmallEmptySection(String title) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isPlansByMe = title == 'Plans by Me';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: isDark
            ? _brandYellow.withValues(alpha: 0.07)
            : const Color(0xFFFFFAEF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? _brandYellow.withValues(alpha: 0.26)
              : const Color(0xFFFFE4AD),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _brandYellow.withValues(alpha: isDark ? 0.20 : 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isPlansByMe
                  ? Icons.add_circle_outline_rounded
                  : Icons.group_add_outlined,
              color: _brandYellow,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isPlansByMe ? 'No plans created yet' : 'No joined plans yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isPlansByMe
                ? 'Create your first plan and start inviting your friends.'
                : 'Join a plan using an invite code from your friends.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: colors.onSurfaceVariant,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanMenu(Plan plan) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canManage = _isAdmin(plan);

    if (!canManage) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'Plan options',
      icon: Icon(
        Icons.more_vert_rounded,
        color: colors.onSurfaceVariant,
        size: 19,
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colors.surface,
      elevation: 8,
      enabled: !_isProcessingAction,
      onSelected: (value) {
        if (value == 'archive') {
          _archivePlan(plan);
        } else if (value == 'delete') {
          _deletePlan(plan);
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem<String>(
            value: 'archive',
            child: _buildPopupItem(
              icon: Icons.archive_outlined,
              label: 'Archive Plan',
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<String>(
            value: 'delete',
            child: _buildPopupItem(
              icon: Icons.delete_outline_rounded,
              label: 'Delete Plan',
              destructive: true,
            ),
          ),
        ];
      },
    );
  }

  Widget _buildDetailedPlanCard(Plan plan) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          _openPlanDashboard(plan);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 114,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.045),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                _buildPlanBanner(plan),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                plan.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            if (_isAdmin(plan))
                              SizedBox(
                                width: 30,
                                height: 24,
                                child: _buildPlanMenu(plan),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _getPlanDateLocationText(plan),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurfaceVariant,
                            height: 1.1,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRolePill(plan),
                            _buildStatusPill(plan.status),
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

  Widget _buildListPlanCard(Plan plan) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          _openPlanDashboard(plan);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 76,
          padding: const EdgeInsets.fromLTRB(17, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 42,
                decoration: BoxDecoration(
                  color: Plan.parseColor(plan.bannerColor),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _getPlanDateLocationText(plan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurfaceVariant,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isAdmin(plan)) _buildPlanMenu(plan),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanBanner(Plan plan) {
    final bannerColor = Plan.parseColor(plan.bannerColor);
    final imageUrl = plan.bannerImageUrl?.trim();

    final bannerBrightness = ThemeData.estimateBrightnessForColor(bannerColor);

    final iconColor = bannerBrightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.82)
        : Colors.black.withValues(alpha: 0.48);

    return SizedBox(
      width: 92,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: bannerColor),
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return ColoredBox(color: bannerColor);
              },
            ),
          if (imageUrl != null && imageUrl.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.30),
                  ],
                ),
              ),
            ),
          Center(
            child: Icon(
              Icons.event_note_rounded,
              size: 28,
              color: imageUrl != null && imageUrl.isNotEmpty
                  ? Colors.white.withValues(alpha: 0.86)
                  : iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePill(Plan plan) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isAdmin = _isAdmin(plan);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isAdmin
            ? _brandYellow.withValues(alpha: isDark ? 0.20 : 0.18)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin ? Icons.star_rounded : Icons.person_outline_rounded,
            size: 12,
            color: isAdmin ? _brandYellowDark : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            isAdmin ? 'Admin' : 'Member',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isAdmin
                  ? (isDark ? _brandYellow : _brandYellowDark)
                  : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final backgroundColor = Plan.getStatusColor(status);

    return Container(
      constraints: const BoxConstraints(minWidth: 88, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
    );
  }
}
