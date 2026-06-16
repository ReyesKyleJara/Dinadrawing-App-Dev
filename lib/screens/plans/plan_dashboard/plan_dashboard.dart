import 'package:flutter/material.dart';

import '../../../services/plan_service.dart';
import '../../../theme/plan_theme_palette.dart';
import '../../myplans/plan_model.dart';
import 'budget/budget_tab.dart';
import 'feed_tab.dart';
import 'members_page.dart';
import 'plan_settings.dart';

class PlanDashboardScreen extends StatefulWidget {
  const PlanDashboardScreen({
    super.key,
    required this.planId,
    this.initialSection = 'feed',
  });

  final int planId;
  final String initialSection;

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

  bool _postEventCheckQueued = false;
  bool _isCheckingPostEvent = false;
  bool _isResolvingPostEvent = false;

  @override
  void initState() {
    super.initState();
    _isFeedActive = widget.initialSection.toLowerCase() != 'budget';
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

      _queuePostEventCheck();
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

  bool _boolValue(dynamic value) {
    return value == true || value == 1 || value == '1' || value == 'true';
  }

  void _queuePostEventCheck() {
    if (_postEventCheckQueued || _isCheckingPostEvent) {
      return;
    }

    _postEventCheckQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _postEventCheckQueued = false;

      if (!mounted) {
        return;
      }

      await _checkPostEventStatus();
    });
  }

  Future<void> _checkPostEventStatus() async {
    if (_isCheckingPostEvent || _isResolvingPostEvent) {
      return;
    }

    _isCheckingPostEvent = true;

    try {
      final result = await PlanService.getPostEventStatus(widget.planId);

      if (!mounted) {
        return;
      }

      if (result['success'] == true && _boolValue(result['should_prompt'])) {
        await _showPostEventPrompt();
      }
    } catch (_) {
      // The dashboard should still work even if the check-up request fails.
    } finally {
      _isCheckingPostEvent = false;
    }
  }

  Future<void> _showPostEventPrompt() async {
    final plan = _selectedPlan;

    if (plan == null || !mounted) {
      return;
    }

    final answer = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;
        final palette = PlanThemePalette.fromHex(
          plan.themeColor,
          brightness: theme.brightness,
        );

        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: palette.soft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: palette.dark,
              size: 30,
            ),
          ),
          title: Text(
            'Did this plan happen?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'The scheduled date for “${plan.title}” has passed. Let us know what happened so the plan stays organized.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, 'later');
              },
              child: const Text('Later'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext, 'no');
              },
              child: const Text('No, It Didn’t'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, 'yes');
              },
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
              ),
              child: const Text(
                'Yes, It Happened',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || answer == null) {
      return;
    }

    if (answer == 'later') {
      await _resolvePostEvent(action: 'later');
      return;
    }

    if (answer == 'yes') {
      await _showHappenedOptions();
      return;
    }

    await _showDidNotHappenOptions();
  }

  Future<void> _showHappenedOptions() async {
    final plan = _selectedPlan;

    if (plan == null || !mounted) {
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;
        final palette = PlanThemePalette.fromHex(
          plan.themeColor,
          brightness: theme.brightness,
        );

        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Mark this plan as completed?',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle_outline, color: palette.dark),
                title: const Text(
                  'Keep Active for Now',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Mark it completed but keep it open for final posts or expenses.',
                ),
                onTap: () {
                  Navigator.pop(dialogContext, 'completed_active');
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.archive_outlined, color: palette.dark),
                title: const Text(
                  'Complete & Archive',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Mark it completed and move it to Archived Plans.',
                ),
                onTap: () {
                  Navigator.pop(dialogContext, 'completed_archive');
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Back'),
            ),
          ],
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    await _resolvePostEvent(action: action);
  }

  Future<void> _showDidNotHappenOptions() async {
    final plan = _selectedPlan;

    if (plan == null || !mounted) {
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;
        final palette = PlanThemePalette.fromHex(
          plan.themeColor,
          brightness: theme.brightness,
        );

        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'What would you like to do?',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_repeat_rounded, color: palette.dark),
                title: const Text(
                  'Reschedule',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Choose a new date and optional time.'),
                onTap: () {
                  Navigator.pop(dialogContext, 'reschedule');
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.pause_circle_outline, color: palette.dark),
                title: const Text(
                  'Decide Later',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Mark it postponed and remove the old schedule.',
                ),
                onTap: () {
                  Navigator.pop(dialogContext, 'postpone');
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Cancel & Archive',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Keep the plan history, but move it out of active plans.',
                ),
                onTap: () {
                  Navigator.pop(dialogContext, 'cancel_archive');
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Back'),
            ),
          ],
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action != 'reschedule') {
      await _resolvePostEvent(action: action);
      return;
    }

    final schedule = await _showRescheduleDialog();

    if (!mounted || schedule == null) {
      return;
    }

    await _resolvePostEvent(
      action: 'reschedule',
      planDate: schedule['plan_date'],
      planTime: schedule['plan_time'],
    );
  }

  Future<Map<String, String?>?> _showRescheduleDialog() async {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay? selectedTime;

    return showDialog<Map<String, String?>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final theme = Theme.of(dialogContext);
            final colors = theme.colorScheme;
            final plan = _selectedPlan;
            final palette = PlanThemePalette.fromHex(
              plan?.themeColor,
              brightness: theme.brightness,
            );
            final dateLabel = MaterialLocalizations.of(
              dialogContext,
            ).formatMediumDate(selectedDate);
            final timeLabel =
                selectedTime?.format(dialogContext) ?? 'No specific time';

            return AlertDialog(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                'Choose a new schedule',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.calendar_month_outlined,
                      color: palette.dark,
                    ),
                    title: const Text('Date'),
                    subtitle: Text(dateLabel),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                        builder: (pickerContext, child) {
                          return Theme(
                            data: Theme.of(pickerContext).copyWith(
                              colorScheme: Theme.of(pickerContext).colorScheme
                                  .copyWith(
                                    primary: palette.primary,
                                    onPrimary: palette.onPrimary,
                                  ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (picked != null && dialogContext.mounted) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.schedule_outlined, color: palette.dark),
                    title: const Text('Time (optional)'),
                    subtitle: Text(timeLabel),
                    trailing: selectedTime == null
                        ? const Icon(Icons.chevron_right_rounded)
                        : IconButton(
                            tooltip: 'Remove time',
                            onPressed: () {
                              setDialogState(() {
                                selectedTime = null;
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                        builder: (pickerContext, child) {
                          return Theme(
                            data: Theme.of(pickerContext).copyWith(
                              colorScheme: Theme.of(pickerContext).colorScheme
                                  .copyWith(
                                    primary: palette.primary,
                                    onPrimary: palette.onPrimary,
                                  ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (picked != null && dialogContext.mounted) {
                        setDialogState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, <String, String?>{
                      'plan_date': _formatApiDate(selectedDate),
                      'plan_time': _formatApiTime(selectedTime),
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                  ),
                  child: const Text(
                    'Reschedule',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String? _formatApiTime(TimeOfDay? time) {
    if (time == null) {
      return null;
    }

    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _resolvePostEvent({
    required String action,
    String? planDate,
    String? planTime,
  }) async {
    if (_isResolvingPostEvent) {
      return;
    }

    _isResolvingPostEvent = true;

    try {
      final result = await PlanService.resolvePostEvent(
        planId: widget.planId,
        action: action,
        planDate: planDate,
        planTime: planTime,
      );

      if (!mounted) {
        return;
      }

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  'Unable to update the plan status.',
            ),
          ),
        );
        return;
      }

      final message = result['message']?.toString() ?? 'Plan updated.';
      final planData = result['plan'];

      if (planData is Map) {
        setState(() {
          _selectedPlan = Plan.fromJson(Map<String, dynamic>.from(planData));
        });
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      if (action == 'completed_archive' || action == 'cancel_archive') {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $error')));
    } finally {
      _isResolvingPostEvent = false;
    }
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
