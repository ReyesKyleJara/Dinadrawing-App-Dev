import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/budget_service.dart';

part 'budget_management.dart';
part 'budget_utils.dart';

const Color _budgetYellow = Color(0xFFF2B73F);
const Color _budgetYellowDark = Color(0xFFD89B22);
const Color _budgetCream = Color(0xFFFFF8E8);

enum _BudgetMenuAction {
  editExpenses,
  manageShares,
  contributionTracking,
  resetBudget,
}

class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key, required this.planId});

  final int planId;

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  bool _isLoading = true;
  bool _isResetting = false;

  String? _pageError;

  Map<String, dynamic>? _budget;
  List<Map<String, dynamic>> _availableMembers = [];

  bool _canManageBudget = false;

  int? _updatingAllocationId;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _pageError = null;
      });
    }

    final result = await BudgetService.getBudget(widget.planId);

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _isLoading = false;
        _pageError = BudgetService.errorMessage(
          result,
          fallback: 'Unable to load the budget plan.',
        );
      });

      return;
    }

    final budget = BudgetService.budgetFromResult(result);

    setState(() {
      _budget = budget;

      _availableMembers = BudgetService.membersFromResult(result);

      _canManageBudget = budget == null
          ? _asBool(result['can_manage_budget'])
          : _asBool(budget['can_manage_budget']);

      _isLoading = false;
      _pageError = null;
    });
  }

  Future<void> _openBudgetEditor({int initialStep = 0}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BudgetPlanEditorPage(
          planId: widget.planId,
          initialBudget: _budget,
          availableMembers: _availableMembers,
          initialStep: initialStep,
        ),
      ),
    );

    if (result == true) {
      await _loadBudget();
    }
  }

  Future<void> _openContributionSettings() async {
    final budget = _budget;

    if (budget == null) {
      return;
    }

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ContributionTrackingSheet(planId: widget.planId, budget: budget);
      },
    );

    if (changed == true) {
      await _loadBudget(showLoading: false);
    }
  }

  Future<void> _confirmResetBudget() async {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restart_alt_rounded,
              color: colors.onErrorContainer,
            ),
          ),
          title: Text(
            'Reset Budget Plan?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'This will permanently remove the planned expenses, member shares, and contribution statuses.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
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
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              child: const Text('Reset Budget'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isResetting = true;
      _pageError = null;
    });

    final result = await BudgetService.resetBudget(widget.planId);

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _isResetting = false;
        _pageError = BudgetService.errorMessage(
          result,
          fallback: 'Unable to reset the budget.',
        );
      });

      return;
    }

    setState(() {
      _budget = null;
      _isResetting = false;
      _pageError = null;
    });

    await _loadBudget(showLoading: false);
  }

  Future<void> _togglePaidStatus(Map<String, dynamic> allocation) async {
    final allocationId = _asInt(allocation['id']);

    if (allocationId == null) {
      setState(() {
        _pageError = 'This contribution record is missing its allocation ID.';
      });

      return;
    }

    final isCurrentlyPaid = _asBool(allocation['is_paid']);

    setState(() {
      _updatingAllocationId = allocationId;
      _pageError = null;
    });

    final result = await BudgetService.setContributionPaidStatus(
      planId: widget.planId,
      allocationId: allocationId,
      isPaid: !isCurrentlyPaid,
    );

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _updatingAllocationId = null;
        _pageError = BudgetService.errorMessage(
          result,
          fallback: 'Unable to update the contribution status.',
        );
      });

      return;
    }

    setState(() {
      _updatingAllocationId = null;
      _pageError = null;
    });

    await _loadBudget(showLoading: false);
  }

  void _handleMenuAction(_BudgetMenuAction action) {
    switch (action) {
      case _BudgetMenuAction.editExpenses:
        _openBudgetEditor(initialStep: 0);
        break;

      case _BudgetMenuAction.manageShares:
        _openBudgetEditor(initialStep: 1);
        break;

      case _BudgetMenuAction.contributionTracking:
        _openContributionSettings();
        break;

      case _BudgetMenuAction.resetBudget:
        _confirmResetBudget();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: const Center(
          child: CircularProgressIndicator(color: _budgetYellow),
        ),
      );
    }

    if (_budget == null) {
      return RefreshIndicator(
        color: _budgetYellow,
        onRefresh: _loadBudget,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 110),
          children: [
            if (_pageError != null) ...[
              _buildInlineError(_pageError!, onRetry: _loadBudget),
              const SizedBox(height: 20),
            ],
            _buildEmptyBudgetState(),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: _budgetYellow,
          onRefresh: _loadBudget,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
            children: [
              _buildPageHeader(),

              const SizedBox(height: 20),

              if (_pageError != null) ...[
                _buildInlineError(
                  _pageError!,
                  onDismiss: () {
                    setState(() {
                      _pageError = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              _buildSummaryCard(),

              const SizedBox(height: 20),

              if (!_trackingEnabled && _canManageBudget) ...[
                _buildTrackingDisabledCard(),
                const SizedBox(height: 26),
              ] else
                const SizedBox(height: 6),

              _buildSectionHeader(
                title: 'Planned Expenses',
                description: 'Breakdown of the group’s estimated costs.',
                actionLabel: _canManageBudget ? 'Edit' : null,
                onAction: _canManageBudget
                    ? () {
                        _openBudgetEditor(initialStep: 0);
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              _buildExpensesCard(),

              const SizedBox(height: 28),

              _buildSectionHeader(
                title: 'Member Shares',
                description: 'Planned share of each included member.',
                actionLabel: _canManageBudget ? 'Manage' : null,
                onAction: _canManageBudget
                    ? () {
                        _openBudgetEditor(initialStep: 1);
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              _buildMemberShares(),

              const SizedBox(height: 22),

              _buildTransparencyFooter(),
            ],
          ),
        ),

        if (_isResetting)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: CircularProgressIndicator(color: _budgetYellow),
              ),
            ),
          ),
      ],
    );
  }

  bool get _trackingEnabled {
    return _asBool(_budget?['contribution_tracking_enabled']);
  }

  Map<String, dynamic> get _summary {
    final rawSummary = _budget?['summary'];

    if (rawSummary is Map) {
      return Map<String, dynamic>.from(rawSummary);
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> get _expenses {
    return _asMapList(_budget?['expenses']);
  }

  List<Map<String, dynamic>> get _allocations {
    return _asMapList(_budget?['allocations']);
  }

  Widget _buildEmptyBudgetState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: isDark
                  ? _budgetYellow.withValues(alpha: 0.16)
                  : _budgetCream,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _budgetYellow.withValues(alpha: 0.45)),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: _budgetYellowDark,
              size: 32,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'No budget plan yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _canManageBudget
                ? 'List the expected expenses and decide how the budget will be divided among the plan members.'
                : 'The Plan Admin has not created a budget for this plan yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),

          if (_canManageBudget) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  _openBudgetEditor();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _budgetYellow,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Set Up Budget',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colors.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Plan expenses and keep member contributions transparent.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        if (_canManageBudget) ...[
          const SizedBox(width: 12),
          PopupMenuButton<_BudgetMenuAction>(
            tooltip: 'Budget menu',
            color: colors.surface,
            surfaceTintColor: Colors.transparent,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: _handleMenuAction,
            itemBuilder: (_) {
              return [
                PopupMenuItem(
                  value: _BudgetMenuAction.editExpenses,
                  child: _buildMenuItem(
                    icon: Icons.edit_note_rounded,
                    label: 'Edit Budget Plan',
                  ),
                ),
                PopupMenuItem(
                  value: _BudgetMenuAction.manageShares,
                  child: _buildMenuItem(
                    icon: Icons.groups_outlined,
                    label: 'Manage Member Shares',
                  ),
                ),
                PopupMenuItem(
                  value: _BudgetMenuAction.contributionTracking,
                  child: _buildMenuItem(
                    icon: Icons.payments_outlined,
                    label: 'Contribution Tracking',
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _BudgetMenuAction.resetBudget,
                  child: _buildMenuItem(
                    icon: Icons.restart_alt_rounded,
                    label: 'Reset Budget',
                    destructive: true,
                  ),
                ),
              ];
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Icon(Icons.more_horiz_rounded, color: colors.onSurface),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    bool destructive = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    final color = destructive ? colors.error : colors.onSurface;

    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 11),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final estimated = _asDouble(_summary['estimated_budget']);

    final allocated = _asDouble(_summary['allocated_amount']);

    final unallocated = _asDouble(_summary['unallocated_amount']);

    final collected = _asDouble(_summary['collected_amount']);

    final notCollected = _asDouble(_summary['not_collected_amount']);

    final includedCount = _allocations
        .where((allocation) => _asBool(allocation['is_included']))
        .length;

    final splitLabel = _budget?['split_type']?.toString() == 'custom'
        ? 'Custom Allocation'
        : 'Split Equally';

    final hasAllocationIssue = unallocated.abs() >= 0.01;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : _budgetCream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _budgetYellow.withValues(alpha: isDark ? 0.42 : 0.58),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _budgetYellow.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _budgetYellowDark,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Budget',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatPeso(estimated),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colors.onSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOverviewChip(
                icon: Icons.balance_rounded,
                label: splitLabel,
              ),
              _buildOverviewChip(
                icon: Icons.groups_outlined,
                label:
                    '$includedCount included member${includedCount == 1 ? '' : 's'}',
              ),
            ],
          ),

          const SizedBox(height: 18),

          Divider(height: 1, color: colors.outlineVariant),

          const SizedBox(height: 17),

          Row(
            children: [
              Expanded(
                child: _buildOverviewMetric(
                  label: 'Allocated',
                  amount: allocated,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              Container(width: 1, height: 46, color: colors.outlineVariant),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOverviewMetric(
                  label: unallocated < 0 ? 'Overallocated' : 'Unallocated',
                  amount: unallocated.abs(),
                  icon: Icons.pie_chart_outline_rounded,
                  warning: hasAllocationIssue,
                ),
              ),
            ],
          ),

          if (_trackingEnabled) ...[
            const SizedBox(height: 17),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewMetric(
                    label: 'Collected',
                    amount: collected,
                    icon: Icons.payments_outlined,
                    success: true,
                  ),
                ),
                Container(width: 1, height: 46, color: colors.outlineVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildOverviewMetric(
                    label: 'Not Yet Collected',
                    amount: notCollected,
                    icon: Icons.schedule_rounded,
                  ),
                ),
              ],
            ),
          ],

          if (hasAllocationIssue) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _budgetYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: _budgetYellowDark,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      unallocated > 0
                          ? '${_formatPeso(unallocated)} still needs to be allocated.'
                          : 'Member shares exceed the budget by ${_formatPeso(unallocated.abs())}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? _budgetYellow : _budgetYellowDark,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewChip({required IconData icon, required String label}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _budgetYellowDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMetric({
    required String label,
    required double amount,
    required IconData icon,
    bool warning = false,
    bool success = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Color valueColor = colors.onSurface;
    Color iconColor = colors.onSurfaceVariant;

    if (warning) {
      valueColor = _budgetYellowDark;
      iconColor = _budgetYellowDark;
    } else if (success) {
      valueColor = const Color(0xFF397044);
      iconColor = const Color(0xFF397044);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _formatPeso(amount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingDisabledCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : _budgetCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _budgetYellow.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _budgetYellow.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: _budgetYellowDark,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contribution tracking is off',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Enable Paid and Unpaid statuses whenever your group needs them.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          TextButton(
            onPressed: _openContributionSettings,
            child: const Text(
              'Enable',
              style: TextStyle(
                color: _budgetYellowDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),

        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: _budgetYellowDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpensesCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'EXPENSE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'ESTIMATED COST',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          ...List.generate(_expenses.length, (index) {
            final expense = _expenses[index];

            final name = expense['name']?.toString() ?? 'Expense';

            final note = expense['note']?.toString().trim();

            final amount = _asDouble(expense['estimated_amount']);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (note != null && note.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                note,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _formatPeso(amount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index != _expenses.length - 1)
                  Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.65),
                  ),
              ],
            );
          }),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceContainerHighest : _budgetCream,
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Estimated Budget',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  _formatPeso(_asDouble(_summary['estimated_budget'])),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberShares() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_allocations.isEmpty) {
      return _buildSimpleMessageCard(
        icon: Icons.group_off_outlined,
        title: 'No members available',
        message: 'There are no plan members assigned to this budget.',
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: List.generate(_allocations.length, (index) {
          return Column(
            children: [
              _buildMemberCard(_allocations[index]),
              if (index != _allocations.length - 1)
                Divider(
                  height: 1,
                  indent: 62,
                  color: colors.outlineVariant.withValues(alpha: 0.65),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> allocation) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final allocationId = _asInt(allocation['id']);

    final included = _asBool(allocation['is_included']);

    final name = allocation['name']?.toString() ?? 'Plan Member';

    final username = allocation['username']?.toString().trim();

    final profilePhotoUrl = allocation['profile_photo_url']?.toString().trim();

    final share = _asDouble(allocation['planned_share']);

    final isPaid = _asBool(allocation['is_paid']);

    final isAdmin = _asBool(allocation['is_plan_admin']);

    final canMarkPaid = _asBool(allocation['can_mark_paid']);

    final isUpdating =
        allocationId != null && allocationId == _updatingAllocationId;

    String memberDescription;

    if (!included) {
      memberDescription = 'Excluded from the budget';
    } else if (_trackingEnabled) {
      memberDescription = 'Planned Share: ${_formatPeso(share)}';
    } else {
      memberDescription = 'Included in the budget';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(name: name, profilePhotoUrl: profilePhotoUrl),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.edit_note_rounded,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),

                if (username != null && username.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    username.startsWith('@') ? username : '@$username',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],

                const SizedBox(height: 5),

                Text(
                  memberDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!included)
                _buildStatusPill(
                  label: 'Excluded',
                  background: colors.surfaceContainerHighest,
                  foreground: colors.onSurfaceVariant,
                )
              else if (_trackingEnabled)
                _buildStatusPill(
                  label: isPaid ? 'Paid' : 'Unpaid',
                  background: isPaid
                      ? const Color(0xFFE2F2E5)
                      : colors.surfaceContainerHighest,
                  foreground: isPaid
                      ? const Color(0xFF397044)
                      : colors.onSurfaceVariant,
                )
              else
                Text(
                  _formatPeso(share),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),

              if (included && _trackingEnabled && canMarkPaid) ...[
                const SizedBox(height: 7),

                if (isUpdating)
                  const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _budgetYellow,
                    ),
                  )
                else
                  InkWell(
                    onTap: () {
                      _togglePaidStatus(allocation);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Text(
                        isPaid ? 'Mark Unpaid' : 'Mark as Paid',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _budgetYellowDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({required String name, String? profilePhotoUrl}) {
    final colors = Theme.of(context).colorScheme;

    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: 21,
      backgroundColor: colors.surfaceContainerHighest,
      foregroundImage: profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
          ? NetworkImage(profilePhotoUrl)
          : null,
      child: Text(
        initial,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildTransparencyFooter() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final updatedBy = _budget?['updated_by'];

    final updatedName = updatedBy is Map ? updatedBy['name']?.toString() : null;

    final updatedAt = _budget?['updated_at'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainerHighest : _budgetCream,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark
              ? colors.outlineVariant
              : _budgetYellow.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 19, color: _budgetYellowDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              updatedName == null
                  ? 'Budget information is visible to all plan members.'
                  : 'Last updated by $updatedName${updatedAt == null ? '' : ' • ${_formatDateTime(updatedAt)}'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleMessageCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors.onSurfaceVariant, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(
    String message, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colors.onErrorContainer,
            size: 19,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onErrorContainer,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Try Again'))
          else if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close_rounded,
                color: colors.onErrorContainer,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}
