import 'package:flutter/material.dart';
import '../settings/settings.dart';
import '../../navigation/main_wrapper.dart';
import '../../services/plan_service.dart';
import '../plans/plan_dashboard/plan_dashboard.dart';
import 'plan_model.dart';
import 'archived_plans_page.dart';
import 'deleted_plans_page.dart';

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

  List<Plan> _plansByMe = [];
  List<Plan> _plansWithMe = [];

  final List<Plan> _archivedPlansByMe = [];
  final List<Plan> _archivedPlansWithMe = [];
  final List<Plan> _deletedPlansByMe = [];
  final List<Plan> _deletedPlansWithMe = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoadingPlans = true;
    });

    try {
      final result = await PlanService.getPlans();

      final plansByMeData = result['plans_by_me'];
      final plansWithMeData = result['plans_with_me'];

      if (!mounted) return;

      setState(() {
        _plansByMe = plansByMeData is List
            ? plansByMeData
                .map((item) => Plan.fromJson(item as Map<String, dynamic>))
                .toList()
            : [];

        _plansWithMe = plansWithMeData is List
            ? plansWithMeData
                .map((item) => Plan.fromJson(item as Map<String, dynamic>))
                .toList()
            : [];

        _isLoadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingPlans = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load plans: $e")),
      );
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

  void _toggleExpansion(String section) {
    setState(() {
      if (section == 'plansByMe') {
        _isPlansByMeExpanded = !_isPlansByMeExpanded;
      } else if (section == 'plansWithMe') {
        _isPlansWithMeExpanded = !_isPlansWithMeExpanded;
      }
    });
  }

  List<Plan> _plansForSection(String sectionId) {
    if (sectionId == 'plansByMe') return _plansByMe;
    if (sectionId == 'plansWithMe') return _plansWithMe;
    if (sectionId == 'archivedPlansByMe') return _archivedPlansByMe;
    if (sectionId == 'archivedPlansWithMe') return _archivedPlansWithMe;
    if (sectionId == 'deletedPlansByMe') return _deletedPlansByMe;
    return _deletedPlansWithMe;
  }

  List<Plan> _archivedPlansForSection(String sectionId) {
    if (sectionId == 'plansByMe' ||
        sectionId == 'archivedPlansByMe' ||
        sectionId == 'deletedPlansByMe') {
      return _archivedPlansByMe;
    }

    return _archivedPlansWithMe;
  }

  List<Plan> _deletedPlansForSection(String sectionId) {
    if (sectionId == 'plansByMe' ||
        sectionId == 'archivedPlansByMe' ||
        sectionId == 'deletedPlansByMe') {
      return _deletedPlansByMe;
    }

    return _deletedPlansWithMe;
  }

  void _archivePlan(String sectionId, Plan plan) {
    final sourcePlans = _plansForSection(sectionId);
    final archivedPlans = _archivedPlansForSection(sectionId);

    setState(() {
      sourcePlans.remove(plan);
      _deletedPlansByMe.remove(plan);
      _deletedPlansWithMe.remove(plan);
      archivedPlans.insert(0, plan);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${plan.title} archived')),
    );
  }

  void _restoreArchivedPlan(String sectionId, Plan plan) {
    final archivedPlans = _archivedPlansForSection(sectionId);
    final sourcePlans =
        sectionId == 'plansWithMe' ? _plansWithMe : _plansByMe;

    setState(() {
      archivedPlans.remove(plan);
      sourcePlans.add(plan);
    });
  }

  void _moveArchivedPlanToDeleted(String sectionId, Plan plan) {
    final archivedPlans = _archivedPlansForSection(sectionId);
    final deletedPlans = _deletedPlansForSection(sectionId);

    setState(() {
      archivedPlans.remove(plan);
      deletedPlans.insert(0, plan);
    });
  }

  void _restoreDeletedPlan(String sectionId, Plan plan) {
    final deletedPlans = _deletedPlansForSection(sectionId);
    final sourcePlans =
        sectionId == 'plansWithMe' ? _plansWithMe : _plansByMe;

    setState(() {
      deletedPlans.remove(plan);
      sourcePlans.add(plan);
    });
  }

  Future<void> _confirmDeletePlan(String sectionId, Plan plan) async {
    final shouldDelete = await _showCustomDialog(
      context,
      title: 'Delete Plan',
      content: 'Delete "${plan.title}"? This cannot be undone.',
      cancelText: 'Cancel',
      confirmText: 'Delete',
      confirmColor: Colors.red.shade400,
    );

    if (shouldDelete == true) {
      if (!mounted) return;

      final sourcePlans = _plansForSection(sectionId);
      final deletedPlans = _deletedPlansForSection(sectionId);

      setState(() {
        sourcePlans.remove(plan);
        _archivedPlansByMe.remove(plan);
        _archivedPlansWithMe.remove(plan);
        deletedPlans.insert(0, plan);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${plan.title} deleted')),
      );
    }
  }

  Future<bool?> _showCustomDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String cancelText,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.grey.shade100,
                      ),
                      child: Text(
                        cancelText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openArchivePlansPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchivePlansPage(
          plansByMe: _archivedPlansByMe,
          plansWithMe: _archivedPlansWithMe,
          onRestore: (sectionId, plan) {
            _restoreArchivedPlan(sectionId, plan);
          },
          onDelete: (sectionId, plan) {
            _moveArchivedPlanToDeleted(sectionId, plan);
          },
        ),
      ),
    );
  }

  void _openDeletedPlansPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeletedPlansPage(
          plansByMe: _deletedPlansByMe,
          plansWithMe: _deletedPlansWithMe,
          onArchive: (sectionId, plan) {
            _restoreDeletedPlan(sectionId, plan);
          },
          onDeletePermanently: (sectionId, plan) {
            setState(() {
              _deletedPlansForSection(sectionId).remove(plan);
            });
          },
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

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                if (_archivedPlansByMe.isNotEmpty ||
                    _archivedPlansWithMe.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildArchivedSection(),
                ],
              ],
              const SizedBox(height: 90),
            ],
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
              color:
                  !_isDetailedView ? Colors.grey.shade200 : Colors.transparent,
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
              color:
                  _isDetailedView ? Colors.grey.shade200 : Colors.transparent,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Image.asset('images/archive.png', width: 18, height: 18),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Image.asset('images/delete.png', width: 18, height: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'Delete Plan',
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
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
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
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _isDetailedView
                  ? _buildDetailedPlanCard(
                      plans[index],
                      sectionId,
                      allowArchive: true,
                    )
                  : _buildListPlanCard(
                      plans[index],
                      sectionId,
                      allowArchive: true,
                    ),
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
              isPlansByMe
                  ? Icons.add_circle_outline
                  : Icons.group_add_outlined,
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

  Widget _buildArchivedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Archived Plans',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        if (_archivedPlansByMe.isNotEmpty) ...[
          const Text(
            'Plans by Me',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _archivedPlansByMe.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _isDetailedView
                ? _buildDetailedPlanCard(
                    _archivedPlansByMe[index],
                    'archivedPlansByMe',
                    allowArchive: false,
                  )
                : _buildListPlanCard(
                    _archivedPlansByMe[index],
                    'archivedPlansByMe',
                    allowArchive: false,
                  ),
          ),
          const SizedBox(height: 16),
        ],
        if (_archivedPlansWithMe.isNotEmpty) ...[
          const Text(
            'Plans with Me',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _archivedPlansWithMe.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _isDetailedView
                ? _buildDetailedPlanCard(
                    _archivedPlansWithMe[index],
                    'archivedPlansWithMe',
                    allowArchive: false,
                  )
                : _buildListPlanCard(
                    _archivedPlansWithMe[index],
                    'archivedPlansWithMe',
                    allowArchive: false,
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlanMenu(
    String sectionId,
    Plan plan, {
    required bool allowArchive,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: Colors.black,
        size: 18,
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 4,
      onSelected: (value) {
        if (value == 'archive') {
          _archivePlan(sectionId, plan);
        } else if (value == 'delete') {
          _confirmDeletePlan(sectionId, plan);
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];

        if (allowArchive) {
          items.add(
            PopupMenuItem(
              value: 'archive',
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Image.asset('images/archive.png', width: 18, height: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'Archive Plan',
                    style: TextStyle(fontSize: 13, color: Colors.black),
                  ),
                ],
              ),
            ),
          );

          items.add(
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
          );
        }

        items.add(
          PopupMenuItem(
            value: 'delete',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Image.asset('images/delete.png', width: 18, height: 18),
                const SizedBox(width: 10),
                const Text(
                  'Delete Plan',
                  style: TextStyle(fontSize: 13, color: Colors.black),
                ),
              ],
            ),
          ),
        );

        return items;
      },
    );
  }

  Widget _buildDetailedPlanCard(
    Plan plan,
    String sectionId, {
    required bool allowArchive,
  }) {
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
                            child: _buildPlanMenu(
                              sectionId,
                              plan,
                              allowArchive: allowArchive,
                            ),
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
                          _buildMemberAvatars(),
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

  Widget _buildListPlanCard(
    Plan plan,
    String sectionId, {
    required bool allowArchive,
  }) {
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
            PopupMenuButton<String>(
              icon: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Plan.getStatusColor(plan.status),
                  shape: BoxShape.circle,
                ),
              ),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              elevation: 4,
              onSelected: (value) {
                if (value == 'archive') {
                  _archivePlan(sectionId, plan);
                } else if (value == 'delete') {
                  _confirmDeletePlan(sectionId, plan);
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<String>>[];

                if (allowArchive) {
                  items.add(
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
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  items.add(
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
                  );
                }

                items.add(
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                return items;
              },
            ),
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

  Widget _buildMemberAvatars() {
    const radius = 10.0;
    const iconSize = 12.0;
    const overlap = 14.0;

    return SizedBox(
      width: 80,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey.shade100,
            child: const Icon(
              Icons.person,
              size: iconSize,
              color: Colors.black,
            ),
          ),
          Positioned(
            left: overlap,
            child: CircleAvatar(
              radius: radius,
              backgroundColor: Colors.grey.shade100,
              child: const Icon(
                Icons.person,
                size: iconSize,
                color: Colors.black,
              ),
            ),
          ),
          Positioned(
            left: overlap * 2,
            child: CircleAvatar(
              radius: radius,
              backgroundColor: Colors.grey.shade100,
              child: const Icon(
                Icons.person,
                size: iconSize,
                color: Colors.black,
              ),
            ),
          ),
          const Positioned(
            left: overlap * 3,
            child: CircleAvatar(
              radius: radius,
              backgroundColor: Color(0xFFE0E0E0),
              child: Text(
                '+3',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
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