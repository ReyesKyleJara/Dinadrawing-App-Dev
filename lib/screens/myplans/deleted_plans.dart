import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/plan_service.dart';
import 'plan_model.dart';

const Color _brandYellow = Color(0xFFF2B73F);
const Color _brandYellowDark = Color(0xFFD89B22);

class DeletedPlansPage extends StatefulWidget {
  const DeletedPlansPage({super.key});

  @override
  State<DeletedPlansPage> createState() => _DeletedPlansPageState();
}

class _DeletedPlansPageState extends State<DeletedPlansPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _loadError;

  int? _currentUserId;

  List<Plan> _plansByMe = <Plan>[];
  List<Plan> _plansWithMe = <Plan>[];

  final Set<int> _selectedPlanIds = <int>{};

  List<Plan> get _allPlans => <Plan>[
        ..._plansByMe,
        ..._plansWithMe,
      ];

  List<Plan> get _selectedPlans {
    return _allPlans
        .where(
          (plan) =>
              plan.id != null && _selectedPlanIds.contains(plan.id),
        )
        .toList();
  }

  bool get _hasSelection => _selectedPlanIds.isNotEmpty;

  bool get _allSelectablePlansSelected {
    final ids = _allPlans.map((plan) => plan.id).whereType<int>().toSet();
    return ids.isNotEmpty && _selectedPlanIds.containsAll(ids);
  }

  @override
  void initState() {
    super.initState();
    _loadDeletedPlans();
  }

  Future<void> _loadDeletedPlans({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final currentUserResult = await AuthService.getCurrentUser();
      final result = await PlanService.getDeletedPlans();

      if (result['success'] == false) {
        throw Exception(
          result['message']?.toString() ?? 'Unable to load deleted plans.',
        );
      }

      final plansByMeData = result['plansByMe'] ?? result['plans_by_me'];
      final plansWithMeData =
          result['plansWithMe'] ?? result['plans_with_me'];

      if (!mounted) return;

      setState(() {
        _currentUserId = _extractCurrentUserId(currentUserResult);
        _plansByMe = _parsePlans(plansByMeData);
        _plansWithMe = _parsePlans(plansWithMeData);
        _selectedPlanIds.clear();
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = _cleanError(error);
      });
    }
  }

  int? _extractCurrentUserId(dynamic raw) {
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw);
    final nestedUser = map['user'];

    if (nestedUser is Map) {
      return _parseInt(nestedUser['id']);
    }

    return _parseInt(map['id']);
  }

  List<Plan> _parsePlans(dynamic raw) {
    if (raw is! List) return <Plan>[];

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
    return id != null && _selectedPlanIds.contains(id);
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    final colors = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : null,
      ),
    );
  }

  void _toggleSelection(Plan plan) {
    final id = plan.id;

    if (id == null) {
      _showMessage('This plan has no valid ID.', isError: true);
      return;
    }

    setState(() {
      if (!_selectedPlanIds.add(id)) {
        _selectedPlanIds.remove(id);
      }
    });
  }

  void _toggleSelectAll() {
    final ids = _allPlans.map((plan) => plan.id).whereType<int>().toSet();

    setState(() {
      if (_allSelectablePlansSelected) {
        _selectedPlanIds.clear();
      } else {
        _selectedPlanIds
          ..clear()
          ..addAll(ids);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedPlanIds.clear);
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Icon(
            destructive
                ? Icons.delete_outline_rounded
                : Icons.unarchive_outlined,
            color: destructive ? colors.error : _brandYellowDark,
            size: 30,
          ),
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            content,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor:
                    destructive ? colors.error : _brandYellow,
                foregroundColor:
                    destructive ? colors.onError : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                confirmText,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _restorePlans(List<Plan> plans) async {
    if (plans.isEmpty || _isProcessing) return;

    final confirmed = await _showConfirmDialog(
      title: plans.length == 1 ? 'Restore this plan?' : 'Restore plans?',
      content: plans.length == 1
          ? '“${plans.first.title}” will return to Active Plans.'
          : '${plans.length} selected plans will return to Active Plans.',
      confirmText: 'Restore',
    );

    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      for (final plan in plans) {
        final id = plan.id;
        if (id == null) continue;

        final result = await PlanService.restorePlan(id);
        if (result['success'] == false) {
          throw Exception(
            result['message']?.toString() ??
                'Unable to restore ${plan.title}.',
          );
        }
      }

      if (!mounted) return;

      await _loadDeletedPlans(showLoading: false);
      _showMessage(
        plans.length == 1
            ? 'Plan restored.'
            : '${plans.length} plans restored.',
      );
    } catch (error) {
      _showMessage(_cleanError(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _deletePlans(List<Plan> plans) async {
    if (plans.isEmpty || _isProcessing) return;

    if (plans.any((plan) => !_isAdmin(plan))) {
      _showMessage(
        'Only plans you administer can be permanently deleted.',
        isError: true,
      );
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: plans.length == 1
          ? 'Delete permanently?'
          : 'Delete plans permanently?',
      content: plans.length == 1
          ? '“${plans.first.title}” will be permanently deleted. This action cannot be undone.'
          : '${plans.length} selected plans will be permanently deleted. This action cannot be undone.',
      confirmText: 'Delete',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      for (final plan in plans) {
        final id = plan.id;
        if (id == null) continue;

        final result = await PlanService.permanentDeletePlan(id);
        if (result['success'] == false) {
          throw Exception(
            result['message']?.toString() ??
                'Unable to delete ${plan.title}.',
          );
        }
      }

      if (!mounted) return;

      await _loadDeletedPlans(showLoading: false);
      _showMessage(
        plans.length == 1
            ? 'Plan permanently deleted.'
            : '${plans.length} plans permanently deleted.',
      );
    } catch (error) {
      _showMessage(_cleanError(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _dateLocation(Plan plan) {
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar:
          _hasSelection ? _buildSelectionBar() : null,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildTopBar(),
            _buildHeader(),
            const SizedBox(height: 14),
            Expanded(
              child: RefreshIndicator(
                color: _brandYellow,
                onRefresh: () => _loadDeletedPlans(showLoading: false),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            onPressed: _isProcessing
                ? null
                : () => Navigator.pop(context, true),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
            label: const Text('Back'),
            style: TextButton.styleFrom(
              foregroundColor: _brandYellowDark,
            ),
          ),
          const Spacer(),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _brandYellow,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isProcessing
                ? null
                : () => _loadDeletedPlans(showLoading: false),
            icon: const Icon(Icons.refresh_rounded),
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Deleted Plans',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: colors.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Plans moved out of your workspace. Restore them, or permanently delete admin-owned plans.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (_allPlans.isNotEmpty) ...<Widget>[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              enabled: !_isProcessing,
              tooltip: 'Selection options',
              color: colors.surface,
              onSelected: (value) {
                if (value == 'toggleAll') {
                  _toggleSelectAll();
                } else if (value == 'clear') {
                  _clearSelection();
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'toggleAll',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _allSelectablePlansSelected
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                    ),
                    title: Text(
                      _allSelectablePlansSelected
                          ? 'Deselect all'
                          : 'Select all',
                    ),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'clear',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.clear_all_rounded),
                    title: Text('Clear selection'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _brandYellow),
      );
    }

    if (_loadError != null) {
      return _buildErrorState();
    }

    if (_allPlans.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
      children: <Widget>[
        if (_plansByMe.isNotEmpty) ...<Widget>[
          _buildSectionHeader(
            label: 'Plans by Me',
            count: _plansByMe.length,
            icon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 10),
          ..._plansByMe.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DeletedPlanCard(
                plan: plan,
                dateLocation: _dateLocation(plan),
                isSelected: _isSelected(plan),
                isAdmin: true,
                isProcessing: _isProcessing,
                onTap: () => _toggleSelection(plan),
                onRestore: () => _restorePlans(<Plan>[plan]),
                onDelete: () => _deletePlans(<Plan>[plan]),
              ),
            ),
          ),
        ],
        if (_plansByMe.isNotEmpty && _plansWithMe.isNotEmpty)
          const SizedBox(height: 12),
        if (_plansWithMe.isNotEmpty) ...<Widget>[
          _buildSectionHeader(
            label: 'Plans with Me',
            count: _plansWithMe.length,
            icon: Icons.groups_2_outlined,
          ),
          const SizedBox(height: 10),
          ..._plansWithMe.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DeletedPlanCard(
                plan: plan,
                dateLocation: _dateLocation(plan),
                isSelected: _isSelected(plan),
                isAdmin: _isAdmin(plan),
                isProcessing: _isProcessing,
                onTap: () => _toggleSelection(plan),
                onRestore: () => _restorePlans(<Plan>[plan]),
                onDelete: _isAdmin(plan)
                    ? () => _deletePlans(<Plan>[plan])
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required String label,
    required int count,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: _brandYellowDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBar() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedPlans = _selectedPlans;
    final canDelete =
        selectedPlans.isNotEmpty && selectedPlans.every(_isAdmin);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.outlineVariant),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.24 : 0.08,
              ),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${selectedPlans.length} selected',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _isProcessing ? null : _clearSelection,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _restorePlans(selectedPlans),
                    icon: const Icon(Icons.unarchive_outlined),
                    label: const Text('Restore'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _brandYellow,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing || !canDelete
                        ? null
                        : () => _deletePlans(selectedPlans),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete forever'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(
                        color: canDelete
                            ? colors.error.withValues(alpha: 0.65)
                            : colors.outlineVariant,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.56,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _brandYellow.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 34,
                      color: _brandYellowDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No deleted plans',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Plans moved to Deleted Plans will stay here until restored or permanently deleted.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.52,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 44,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _loadError ?? 'Unable to load deleted plans.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadDeletedPlans,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeletedPlanCard extends StatelessWidget {
  const _DeletedPlanCard({
    required this.plan,
    required this.dateLocation,
    required this.isSelected,
    required this.isAdmin,
    required this.isProcessing,
    required this.onTap,
    required this.onRestore,
    required this.onDelete,
  });

  final Plan plan;
  final String dateLocation;
  final bool isSelected;
  final bool isAdmin;
  final bool isProcessing;
  final VoidCallback onTap;
  final VoidCallback onRestore;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bannerColor = Plan.parseColor(plan.bannerColor);
    final hasBannerImage =
        plan.bannerImageUrl?.trim().isNotEmpty ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: plan.id == null || isProcessing ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected
                ? _brandYellow.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.12 : 0.08,
                  )
                : colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? _brandYellow
                  : colors.outlineVariant.withValues(alpha: 0.75),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.16 : 0.04,
                ),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          constraints: const BoxConstraints(minHeight: 116),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 78,
                height: 116,
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(17),
                  ),
                  child: hasBannerImage
                      ? Image.network(
                          plan.bannerImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildFallbackMedia(
                            bannerColor,
                          ),
                        )
                      : _buildFallbackMedia(bannerColor),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 4, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.place_outlined,
                            size: 15,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              dateLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: <Widget>[
                          _buildChip(
                            context,
                            label: 'Deleted',
                            icon: Icons.delete_outline_rounded,
                          ),
                          _buildChip(
                            context,
                            label: isAdmin ? 'Admin' : 'Member',
                            icon: isAdmin
                                ? Icons.admin_panel_settings_outlined
                                : Icons.person_outline_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Checkbox(
                    value: isSelected,
                    activeColor: _brandYellow,
                    checkColor: Colors.black,
                    onChanged: plan.id == null || isProcessing
                        ? null
                        : (_) => onTap(),
                  ),
                  PopupMenuButton<String>(
                    enabled: plan.id != null && !isProcessing,
                    tooltip: 'Plan actions',
                    color: colors.surface,
                    onSelected: (value) {
                      if (value == 'restore') {
                        onRestore();
                      } else if (value == 'delete') {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'restore',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.unarchive_outlined),
                          title: Text('Restore'),
                        ),
                      ),
                      if (onDelete != null)
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              color: colors.error,
                            ),
                            title: Text(
                              'Delete permanently',
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackMedia(Color bannerColor) {
    return ColoredBox(
      color: bannerColor,
      child: Center(
        child: Icon(
          Icons.delete_outline_rounded,
          color: PlanThemeContrast.onColor(bannerColor),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class PlanThemeContrast {
  const PlanThemeContrast._();

  static Color onColor(Color color) {
    return color.computeLuminance() > 0.55
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.86);
  }
}
