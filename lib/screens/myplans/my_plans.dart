import 'package:flutter/material.dart';

import '../../navigation/main_wrapper.dart';
import '../../services/auth_service.dart';
import '../../services/plan_service.dart';
import '../plans/plan_dashboard/plan_dashboard.dart';
import '../settings/settings.dart';
import 'archived_plans.dart';
import 'deleted_plans.dart';
import 'plan_model.dart';

class MyPlansScreen extends StatefulWidget {
  const MyPlansScreen({super.key});

  @override
  State<MyPlansScreen> createState() => _MyPlansScreenState();
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
      final currentUser = await AuthService.getCurrentUser();
      final result = await PlanService.getPlans();

      if (!mounted) return;

      setState(() {
        _currentUserId = _parseInt(currentUser?['id']);
        _plansByMe = _parsePlans(result['plans_by_me']);
        _plansWithMe = _parsePlans(result['plans_with_me']);
        _isLoadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingPlans = false;
      });

      _showSnackBar('Failed to load plans: $e');
    }
  }

  List<Plan> _parsePlans(dynamic raw) {
    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((item) => Plan.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool _isAdmin(Plan plan) {
    return _currentUserId != null && plan.adminId == _currentUserId;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openPlanDashboard(Plan plan) {
    if (plan.id == null) {
      _showSnackBar('Unable to open plan. Missing plan ID.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanDashboardScreen(planId: plan.id!),
      ),
    ).then((_) => _loadPlans());
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
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(
            color: Colors.black87,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              confirmText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runPlanAction(Future<void> Function() action) async {
    if (_isProcessingAction) return;

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
      _showSnackBar('Only the plan admin can archive this plan.');
      return;
    }

    if (plan.id == null) {
      _showSnackBar('Unable to archive plan. Missing plan ID.');
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Archive Plan',
      content: 'Archive "${plan.title}"? You can restore it later.',
      confirmText: 'Archive',
      confirmColor: const Color(0xFFF2B73F),
    );

    if (confirmed != true) return;

    await _runPlanAction(() async {
      final result = await PlanService.archivePlan(plan.id!);
      _showSnackBar(result['message']?.toString() ?? '${plan.title} archived.');
    });
  }

  Future<void> _deletePlan(Plan plan) async {
    if (!_isAdmin(plan)) {
      _showSnackBar('Only the plan admin can delete this plan.');
      return;
    }

    if (plan.id == null) {
      _showSnackBar('Unable to delete plan. Missing plan ID.');
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Delete Plan',
      content: 'Move "${plan.title}" to Deleted Plans?',
      confirmText: 'Delete',
      confirmColor: Colors.red.shade400,
    );

    if (confirmed != true) return;

    await _runPlanAction(() async {
      final result = await PlanService.deletePlan(plan.id!);

      if (result['success'] == false) {
        _showSnackBar(result['message']?.toString() ?? 'Failed to delete plan.');
        return;
      }

      _showSnackBar(
        result['message']?.toString() ?? '${plan.title} moved to Deleted Plans.',
      );
    });
  }

  void _openArchivePlansPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ArchivedPlansPage(),
      ),
    ).then((_) => _loadPlans());
  }

  void _openDeletedPlansPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DeletedPlansPage(),
      ),
    ).then((_) => _loadPlans());
  }

  String _getPlanDateLocationText(Plan plan) {
    final hasDate = plan.date.trim().isNotEmpty;
    final hasLocation = plan.location.trim().isNotEmpty;

    if (hasDate && hasLocation) {
      return '${plan.date} • ${plan.location}';
    }

    if (hasDate) return plan.date;
    if (hasLocation) return plan.location;

    return 'No date or location yet';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: const Color(0xFFF2B73F),
        onRefresh: _loadPlans,
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
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Plans',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
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
                      child: CircularProgressIndicator(
                        color: Color(0xFFF2B73F),
                      ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Plans',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage, view, and edit your plans easily.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7A7F8F),
                  height: 1.2,
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

  Widget _buildFilterBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isDetailedView = false),
          child: Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: !_isDetailedView ? Colors.grey.shade200 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'images/list.png',
              color: !_isDetailedView ? Colors.black : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _isDetailedView = true),
          child: Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isDetailedView ? Colors.grey.shade200 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'images/grid.png',
              color: _isDetailedView ? Colors.black : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert,
            size: 22,
            color: Colors.black,
          ),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          offset: const Offset(0, 40),
          elevation: 4,
          onSelected: (value) {
            if (value == 'archive') {
              _openArchivePlansPage();
            } else if (value == 'delete') {
              _openDeletedPlansPage();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'archive',
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Image.asset(
                    'images/archive.png',
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Archived Plans',
                    style: TextStyle(fontSize: 13, color: Colors.black),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              enabled: false,
              height: 1,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFEEEEEE),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Image.asset(
                    'images/delete.png',
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Deleted Plans',
                    style: TextStyle(fontSize: 13, color: Colors.black),
                  ),
                ],
              ),
            ),
          ],
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
    return Column(
      children: [
        GestureDetector(
          onTap: () => _toggleExpansion(sectionId),
          child: Row(
            children: [
              Icon(
                isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                color: Colors.black,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 14),
          if (plans.isEmpty)
            _buildSmallEmptySection(title)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: plans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final plan = plans[index];

                return _isDetailedView
                    ? _buildDetailedPlanCard(plan)
                    : _buildListPlanCard(plan);
              },
            ),
        ],
      ],
    );
  }

  Widget _buildSmallEmptySection(String title) {
    final bool isPlansByMe = title == 'Plans by Me';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF2B73F).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isPlansByMe ? Icons.add_circle_outline : Icons.group_add_outlined,
              color: const Color(0xFFF2B73F),
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isPlansByMe ? 'No plans created yet' : 'No joined plans yet',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isPlansByMe
                ? 'Create your first plan and start inviting your friends.'
                : 'Join a plan using an invite code from your friends.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey[600],
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanMenu(Plan plan) {
    final bool canManage = _isAdmin(plan);

    if (!canManage) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: Colors.black,
        size: 18,
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      elevation: 4,
      enabled: !_isProcessingAction,
      onSelected: (value) {
        if (value == 'archive') {
          _archivePlan(plan);
        } else if (value == 'delete') {
          _deletePlan(plan);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'archive',
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          child: Row(
            children: [
              Image.asset(
                'images/archive.png',
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 10),
              const Text(
                'Archive Plan',
                style: TextStyle(fontSize: 13, color: Colors.black),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          enabled: false,
          height: 1,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFEEEEEE),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          child: Row(
            children: [
              Image.asset(
                'images/delete.png',
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 10),
              const Text(
                'Delete Plan',
                style: TextStyle(fontSize: 13, color: Colors.black),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedPlanCard(Plan plan) {
    return GestureDetector(
      onTap: () => _openPlanDashboard(plan),
      child: Container(
        height: 112,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE6E8EE),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              _buildPlanBanner(plan),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                height: 1.1,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 26,
                            height: 22,
                            child: _buildPlanMenu(plan),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getPlanDateLocationText(plan),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
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
    );
  }

  Widget _buildListPlanCard(Plan plan) {
    return GestureDetector(
      onTap: () => _openPlanDashboard(plan),
      child: Container(
        height: 74,
        padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE6E8EE),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _getPlanDateLocationText(plan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildPlanMenu(plan),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanBanner(Plan plan) {
    final Color bannerColor = Plan.parseColor(plan.bannerColor);

    return Container(
      width: 92,
      height: double.infinity,
      color: bannerColor,
      child: Center(
        child: Icon(
          Icons.event,
          size: 26,
          color: Colors.black.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _buildRolePill(Plan plan) {
    final isAdmin = _isAdmin(plan);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFFFFF3D2) : const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'Member',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final bgColor = Plan.getStatusColor(status);

    return Container(
      constraints: const BoxConstraints(
        minWidth: 88,
        minHeight: 28,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }
}