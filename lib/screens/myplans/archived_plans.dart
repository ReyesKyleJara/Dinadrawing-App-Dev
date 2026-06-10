import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/plan_service.dart';
import 'plan_model.dart';

class ArchivedPlansPage extends StatefulWidget {
  const ArchivedPlansPage({super.key});

  @override
  State<ArchivedPlansPage> createState() => _ArchivedPlansPageState();
}

class _ArchivedPlansPageState extends State<ArchivedPlansPage> {
  bool _isLoading = true;
  bool _isProcessing = false;

  int? _currentUserId;

  List<Plan> _plansByMe = [];
  List<Plan> _plansWithMe = [];

  final Set<int> _selectedPlanIds = <int>{};

  List<_PlanEntry> get _allEntries => [
        ..._plansByMe.map(
          (plan) => _PlanEntry(
            plan: plan,
            sectionLabel: 'Plans by Me',
          ),
        ),
        ..._plansWithMe.map(
          (plan) => _PlanEntry(
            plan: plan,
            sectionLabel: 'Plans with Me',
          ),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadArchivedPlans();
  }

  Future<void> _loadArchivedPlans() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = await AuthService.getCurrentUser();
      final result = await PlanService.getArchivedPlans();

      final plansByMeData = result['plansByMe'] ?? result['plans_by_me'];
      final plansWithMeData = result['plansWithMe'] ?? result['plans_with_me'];

      if (!mounted) return;

      setState(() {
        _currentUserId = _parseInt(currentUser?['id']);
        _plansByMe = _parsePlans(plansByMeData);
        _plansWithMe = _parsePlans(plansWithMeData);
        _selectedPlanIds.clear();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showSnackBar('Failed to load archived plans: $e');
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

  bool _isSelected(Plan plan) {
    final id = plan.id;
    if (id == null) return false;
    return _selectedPlanIds.contains(id);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _toggleSelection(Plan plan) {
    final id = plan.id;

    if (id == null) {
      _showSnackBar('This plan has no valid ID.');
      return;
    }

    setState(() {
      if (_selectedPlanIds.contains(id)) {
        _selectedPlanIds.remove(id);
      } else {
        _selectedPlanIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPlanIds
        ..clear()
        ..addAll(
          _allEntries.map((entry) => entry.plan.id).whereType<int>(),
        );
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPlanIds.clear();
    });
  }

  List<Plan> _selectedPlans() {
    return _allEntries
        .map((entry) => entry.plan)
        .where((plan) => plan.id != null && _selectedPlanIds.contains(plan.id))
        .toList();
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

  Future<void> _restoreSelected() async {
    final selectedPlans = _selectedPlans();

    if (selectedPlans.isEmpty) {
      _showSnackBar('Please select at least one plan.');
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Restore Plan',
      content: selectedPlans.length == 1
          ? 'Restore "${selectedPlans.first.title}" back to Active Plans?'
          : 'Restore ${selectedPlans.length} plans back to Active Plans?',
      confirmText: 'Restore',
      confirmColor: const Color(0xFFF2B73F),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      for (final plan in selectedPlans) {
        await PlanService.unarchivePlan(plan.id!);
      }

      if (!mounted) return;

      await _loadArchivedPlans();

      _showSnackBar('${selectedPlans.length} plan(s) restored.');
    } catch (e) {
      _showSnackBar('Restore failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _deleteSelected() async {
    final selectedPlans = _selectedPlans();

    if (selectedPlans.isEmpty) {
      _showSnackBar('Please select at least one plan.');
      return;
    }

    if (selectedPlans.any((plan) => !_isAdmin(plan))) {
      _showSnackBar('Only plan admins can delete plans.');
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Delete Plan',
      content: selectedPlans.length == 1
          ? 'Move "${selectedPlans.first.title}" to Deleted Plans?'
          : 'Move ${selectedPlans.length} plans to Deleted Plans?',
      confirmText: 'Delete',
      confirmColor: Colors.red.shade400,
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      for (final plan in selectedPlans) {
        await PlanService.deletePlan(plan.id!);
      }

      if (!mounted) return;

      await _loadArchivedPlans();

      _showSnackBar('${selectedPlans.length} plan(s) moved to Deleted Plans.');
    } catch (e) {
      _showSnackBar('Delete failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _restoreSingle(Plan plan) async {
    if (plan.id == null) return;

    setState(() {
      _selectedPlanIds
        ..clear()
        ..add(plan.id!);
    });

    await _restoreSelected();
  }

  Future<void> _deleteSingle(Plan plan) async {
    if (plan.id == null) return;

    setState(() {
      _selectedPlanIds
        ..clear()
        ..add(plan.id!);
    });

    await _deleteSelected();
  }

  String _dateLocation(Plan plan) {
    final hasDate = plan.date.trim().isNotEmpty;
    final hasLocation = plan.location.trim().isNotEmpty;

    if (hasDate && hasLocation) return '${plan.date} • ${plan.location}';
    if (hasDate) return plan.date;
    if (hasLocation) return plan.location;

    return 'No date or location yet';
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedPlanIds.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildHeader(),
            const SizedBox(height: 18),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFF2B73F),
                onRefresh: _loadArchivedPlans,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFF2B73F),
                        ),
                      )
                    : _allEntries.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 180),
                              Center(
                                child: Text(
                                  'No archived plans yet.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: _allEntries.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final entry = _allEntries[index];
                              final plan = entry.plan;

                              return _ArchivedPlanCard(
                                plan: plan,
                                sectionLabel: entry.sectionLabel,
                                dateLocation: _dateLocation(plan),
                                isSelected: _isSelected(plan),
                                isAdmin: _isAdmin(plan),
                                onTap: () => _toggleSelection(plan),
                                onRestore: _isProcessing ? null : () => _restoreSingle(plan),
                                onDelete: !_isAdmin(plan) || _isProcessing
                                    ? null
                                    : () => _deleteSingle(plan),
                              );
                            },
                          ),
              ),
            ),
            if (hasSelection) _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            color: const Color(0xFFF2B73F),
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(width: 6),
          const Text(
            'Back',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _isProcessing ? null : _loadArchivedPlans,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archived Plans',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Restore archived plans or move admin-owned plans to Deleted Plans.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (_allEntries.isNotEmpty)
            PopupMenuButton<String>(
              enabled: !_isProcessing,
              onSelected: (value) {
                if (value == 'selectAll') {
                  _selectAll();
                } else if (value == 'clear') {
                  _clearSelection();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'selectAll',
                  child: Text('Select All'),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Text('Clear Selection'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final selectedPlans = _selectedPlans();
    final canDelete = selectedPlans.isNotEmpty && selectedPlans.every(_isAdmin);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _restoreSelected,
              icon: const Icon(Icons.restore, color: Colors.white),
              label: const Text(
                'Restore',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF2B73F),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing || !canDelete ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedPlanCard extends StatelessWidget {
  const _ArchivedPlanCard({
    required this.plan,
    required this.sectionLabel,
    required this.dateLocation,
    required this.isSelected,
    required this.isAdmin,
    required this.onTap,
    required this.onRestore,
    required this.onDelete,
  });

  final Plan plan;
  final String sectionLabel;
  final String dateLocation;
  final bool isSelected;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final bannerColor = Plan.parseColor(plan.bannerColor);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: plan.id == null ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFF2B73F) : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 76,
              height: 92,
              decoration: BoxDecoration(
                color: bannerColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
              ),
              child: Icon(
                Icons.archive_outlined,
                color: Colors.black.withOpacity(0.45),
                size: 26,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$sectionLabel • ${isAdmin ? "Admin" : "Member"}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Checkbox(
              value: isSelected,
              activeColor: const Color(0xFFF2B73F),
              onChanged: plan.id == null ? null : (_) => onTap(),
            ),
            PopupMenuButton<String>(
              enabled: plan.id != null,
              onSelected: (value) {
                if (value == 'restore') {
                  onRestore?.call();
                } else if (value == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (_) {
                final items = <PopupMenuEntry<String>>[
                  const PopupMenuItem(
                    value: 'restore',
                    child: Text('Restore'),
                  ),
                ];

                if (isAdmin) {
                  items.add(
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  );
                }

                return items;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanEntry {
  _PlanEntry({
    required this.plan,
    required this.sectionLabel,
  });

  final Plan plan;
  final String sectionLabel;
}