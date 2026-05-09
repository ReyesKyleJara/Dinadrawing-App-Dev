import 'package:flutter/material.dart';
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

  final List<Plan> _plansByMe = [
    Plan(
      title: 'Picnic with Family',
      date: 'Apr 15',
      location: 'Kahit saang tabing ilog',
      status: 'Planned',
      statusColor: const Color(0xFFB8E4C1),
      imagePath: 'images/picnic.png',
    ),
    Plan(
      title: 'Birthday ni Kenny',
      date: 'Apr 29',
      location: 'Boracay, Philippines',
      status: 'Plan Ongoing',
      statusColor: const Color(0xFFFFE4AD),
      imagePath: 'images/birthday.png',
    ),
  ];

  final List<Plan> _plansWithMe = [
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

  final List<Plan> _archivedPlansByMe = [];
  final List<Plan> _archivedPlansWithMe = [];
  final List<Plan> _deletedPlansByMe = [];
  final List<Plan> _deletedPlansWithMe = [];

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
    if (sectionId == 'plansByMe' || sectionId == 'archivedPlansByMe' || sectionId == 'deletedPlansByMe') {
      return _archivedPlansByMe;
    }
    return _archivedPlansWithMe;
  }

  List<Plan> _deletedPlansForSection(String sectionId) {
    if (sectionId == 'plansByMe' || sectionId == 'archivedPlansByMe' || sectionId == 'deletedPlansByMe') {
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
    final sourcePlans = _plansForSection(sectionId);

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
    final sourcePlans = _plansForSection(sectionId);

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
      if (!mounted) {
        return;
      }
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: Colors.grey.shade100,
                      ),
                      child: Text(
                        cancelText,
                        style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
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
              _buildExpansionSection(
                'Plans by Me',
                _plansByMe,
                _isPlansByMeExpanded,
                'plansByMe',
              ),
              const SizedBox(height: 16),
              _buildExpansionSection(
                'Plans with Me',
                _plansWithMe,
                _isPlansWithMeExpanded,
                'plansWithMe',
              ),
              if (_archivedPlansByMe.isNotEmpty || _archivedPlansWithMe.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildArchivedSection(),
              ],
              const SizedBox(height: 80),
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
        // SAFE AVATAR: Won't crash if the image is missing (copied from activity.dart)
        // Match Home avatar size (smaller)
        ClipOval(
          child: Image.asset(
            'images/user-avatar.png', // Change this to your actual image path
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const CircleAvatar(
              radius: 19,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        // 1. List View Button
        GestureDetector(
          onTap: () => setState(() => _isDetailedView = false),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              // Gray background when this view is active
              color: !_isDetailedView ? Colors.grey.shade200 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'images/list.png',
              width: 14,
              height: 14,
              // Darkens the image when active, makes it gray when inactive
              color: !_isDetailedView ? Colors.black : Colors.grey[500],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Grid View Button
        GestureDetector(
          onTap: () => setState(() => _isDetailedView = true),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              // Gray background when this view is active
              color: _isDetailedView ? Colors.grey.shade200 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'images/grid.png',
              width: 14,
              height: 14,
              // Darkens the image when active, makes it gray when inactive
              color: _isDetailedView ? Colors.black : Colors.grey[500],
            ),
          ),
        ),
        const SizedBox(width: 4),

        // 3. More Menu Button
        PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              // DITO: Ginawa nating transparent imbis na grey.shade200
              color: Colors.transparent, 
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'images/menu-myplans.png', 
              width: 16, 
              height: 16, 
              // DITO: Ginawa nating grey[700] para pantay sa ibang inactive icons
              color: Colors.grey[700], 
            ),
          ),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          offset: const Offset(0, 45), 
          elevation: 4,
          onSelected: (value) {
            if (value == 'archive') {
              _openArchivePlansPage();
            } else if (value == 'delete') {
              _openDeletedPlansPage();
            }
          },
          itemBuilder: (context) => [
            // --- ARCHIVE ITEM ---
            PopupMenuItem(
              value: 'archive',
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Pinaliit ang icon
                  Image.asset('images/archive.png', width: 18, height: 18), 
                  const SizedBox(width: 10),
                  // Pinaliit ang text
                  const Text('Archive Plan', style: TextStyle(fontSize: 13, color: Colors.black)),
                ],
              ),
            ),
            
            // --- CUSTOM DIVIDER ---
            const PopupMenuItem(
              enabled: false,
              height: 1,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            ),

            // --- DELETE ITEM ---
            PopupMenuItem(
              value: 'delete',
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Pinaliit ang icon
                  Image.asset('images/delete.png', width: 18, height: 18), 
                  const SizedBox(width: 10),
                  // Pinaliit ang text
                  const Text('Delete Plan', style: TextStyle(fontSize: 13, color: Colors.black)),
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
                ? _buildDetailedPlanCard(plans[index], sectionId, allowArchive: true)
                : _buildCompactPlanCard(plans[index], sectionId, allowArchive: true),
          ),
        ]
      ],
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
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _isDetailedView
                ? _buildDetailedPlanCard(_archivedPlansByMe[index], 'archivedPlansByMe', allowArchive: false)
                : _buildCompactPlanCard(_archivedPlansByMe[index], 'archivedPlansByMe', allowArchive: false),
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
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _isDetailedView
                ? _buildDetailedPlanCard(_archivedPlansWithMe[index], 'archivedPlansWithMe', allowArchive: false)
                : _buildCompactPlanCard(_archivedPlansWithMe[index], 'archivedPlansWithMe', allowArchive: false),
          ),
        ],
      ],
    );
  }

  Widget _buildPlanMenu(String sectionId, Plan plan, {required bool allowArchive}) {
    return PopupMenuButton<String>(
      icon: Image.asset('images/menu-myplans.png', width: 16, height: 16, color: Colors.grey[600]), 
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
                  // Pinaliit ang icon
                  Image.asset('images/archive.png', width: 18, height: 18),
                  const SizedBox(width: 10),
                  // Pinaliit ang text
                  const Text('Archive Plan', style: TextStyle(fontSize: 13, color: Colors.black)),
                ],
              ),
            ),
          );
          
          items.add(
            const PopupMenuItem(
              enabled: false,
              height: 1,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            ),
          );
        }
        
        items.add(
          PopupMenuItem(
            value: 'delete',
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Pinaliit ang icon
                Image.asset('images/delete.png', width: 18, height: 18),
                const SizedBox(width: 10),
                // Pinaliit ang text
                const Text('Delete Plan', style: TextStyle(fontSize: 13, color: Colors.black)),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 80,
              height: 100,
              color: Colors.grey.shade200,
              child: Image.asset(
                plan.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.image_outlined, color: Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        plan.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildPlanMenu(sectionId, plan, allowArchive: allowArchive),
                  ],
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
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildCompactPlanCard(
    Plan plan,
    String sectionId, {
    required bool allowArchive,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
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
          _buildPlanMenu(sectionId, plan, allowArchive: allowArchive),
          const SizedBox(width: 8),
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

