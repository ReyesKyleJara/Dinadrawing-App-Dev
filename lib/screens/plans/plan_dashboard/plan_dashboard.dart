import 'package:flutter/material.dart';

import '../../../services/plan_service.dart';
import '../../../theme/plan_theme_palette.dart';
import '../../myplans/plan_model.dart';
import 'budget/budget_tab.dart';
import 'feed_tab.dart';
import 'members_page.dart';
import 'plan_settings.dart';

class PlanDashboardScreen extends StatefulWidget {
  const PlanDashboardScreen({super.key, required this.planId});

  final int planId;

  @override
  State<PlanDashboardScreen> createState() {
    return _PlanDashboardScreenState();
  }
}

class _PlanDashboardScreenState extends State<PlanDashboardScreen> {
  bool _isFeedActive = true;

  Plan? _selectedPlan;
  bool _isLoadingPlan = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSelectedPlan();
  }

  Future<void> _loadSelectedPlan() async {
    try {
      final result = await PlanService.getPlanById(widget.planId);

      if (!mounted) {
        return;
      }

      final planData = result['plan'];

      if (planData is! Map) {
        setState(() {
          _errorMessage = result['message']?.toString() ?? 'Plan not found.';
          _isLoadingPlan = false;
        });
        return;
      }

      setState(() {
        _selectedPlan = Plan.fromJson(Map<String, dynamic>.from(planData));
        _isLoadingPlan = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Failed to load plan: $error';
        _isLoadingPlan = false;
      });
    }
  }

  Future<void> _refreshPlanDetails() async {
    if (!mounted) {
      return;
    }

    await _loadSelectedPlan();
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return PlanSettingsPage(planId: widget.planId);
        },
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == 'deleted' || result == 'left') {
      Navigator.pop(context, true);
      return;
    }

    if (result == true) {
      setState(() {
        _isLoadingPlan = true;
      });

      await _loadSelectedPlan();
    }
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoadingPlan) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFF2B73F)),
        ),
      );
    }

    if (_errorMessage != null || _selectedPlan == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: colors.surface,
          foregroundColor: colors.onSurface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Plan Dashboard'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage ?? 'Unable to load plan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final plan = _selectedPlan!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: <Widget>[
          _buildBannerHeader(plan),
          _buildTabSwitcher(plan),
          Expanded(
            child: _isFeedActive
                ? FeedTab(
                    planId: widget.planId,
                    themeColor: plan.themeColor,
                    onPlanDetailsChanged: _refreshPlanDetails,
                  )
                : BudgetTab(planId: widget.planId, themeColor: plan.themeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerHeader(Plan plan) {
    final bannerColor = Plan.parseColor(plan.bannerColor);
    final hasImage = plan.bannerImageUrl?.trim().isNotEmpty == true;
    final dateLocationText = _getPlanDateLocationText(plan);

    final colorBrightness = ThemeData.estimateBrightnessForColor(bannerColor);
    final foregroundColor = hasImage
        ? Colors.white
        : colorBrightness == Brightness.dark
        ? Colors.white
        : Colors.black87;

    final secondaryForeground = foregroundColor.withValues(alpha: 0.76);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: ColoredBox(color: bannerColor)),
          if (hasImage)
            Positioned.fill(
              child: Image.network(
                plan.bannerImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return ColoredBox(color: bannerColor);
                },
              ),
            ),
          if (hasImage)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.14),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _buildHeaderIconButton(
                        icon: Icons.arrow_back_rounded,
                        color: foregroundColor,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      Row(
                        children: <Widget>[
                          _buildHeaderIconButton(
                            icon: Icons.person_add_alt_1_rounded,
                            color: foregroundColor,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) {
                                    return MembersPage(planId: widget.planId);
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          _buildHeaderIconButton(
                            icon: Icons.settings_outlined,
                            color: foregroundColor,
                            onPressed: _openSettings,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    plan.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: foregroundColor,
                      height: 1.08,
                      shadows: hasImage
                          ? const <Shadow>[
                              Shadow(color: Colors.black38, blurRadius: 6),
                            ]
                          : null,
                    ),
                  ),
                  if (dateLocationText.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      dateLocationText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: secondaryForeground,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
      ),
    );
  }

  Widget _buildTabSwitcher(Plan plan) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = PlanThemePalette.fromHex(
      plan.themeColor,
      brightness: theme.brightness,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 45,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _buildTabButton(
                label: 'Feed',
                selected: _isFeedActive,
                palette: palette,
                onTap: () {
                  setState(() {
                    _isFeedActive = true;
                  });
                },
              ),
            ),
            Expanded(
              child: _buildTabButton(
                label: 'Budget',
                selected: !_isFeedActive,
                palette: palette,
                onTap: () {
                  setState(() {
                    _isFeedActive = false;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool selected,
    required PlanThemePalette palette,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? palette.onPrimary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
