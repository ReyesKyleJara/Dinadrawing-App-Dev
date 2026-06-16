import 'package:flutter/material.dart';

import '../../navigation/main_wrapper.dart';
import '../../services/auth_service.dart';
import '../../services/plan_service.dart';
import '../../services/profile_service.dart';
import '../plans/plan_dashboard/plan_dashboard.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    this.onUnreadCountChanged,
    this.onPlanAccepted,
  });

  final ValueChanged<int>? onUnreadCountChanged;
  final VoidCallback? onPlanAccepted;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const Color _brandYellow = Color(0xFFF2B73F);
  static const Color _brandYellowDark = Color(0xFFD89B22);

  bool _isLoading = true;
  bool _isMarkingAllRead = false;
  String? _loadError;

  List<Map<String, dynamic>> _activities = <Map<String, dynamic>>[];

  final Set<String> _processingActivityKeys = <String>{};
  final Map<String, String> _actionErrors = <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
    _loadActivity();
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final settingsResult = await AuthService.getUserSettings();
      Map<String, dynamic>? user;

      final rawUser = settingsResult['user'];
      if (rawUser is Map) {
        user = Map<String, dynamic>.from(rawUser);
      }

      user ??= await AuthService.getCurrentUser();

      if (user != null) {
        ProfileService.instance.syncFromUser(
          user,
          clearAvatarWhenMissing: true,
        );
      }
    } catch (error) {
      debugPrint('ACTIVITY USER LOAD ERROR: $error');
    }
  }

  Future<void> _loadActivity({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    final result = await PlanService.getActivityFeed();

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _isLoading = false;
        _loadError = _cleanText(result['message']).isNotEmpty
            ? _cleanText(result['message'])
            : 'Unable to load activity.';
      });
      return;
    }

    final rawActivities = result['activities'];
    final activities = rawActivities is List
        ? rawActivities
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    activities.sort((first, second) {
      final firstDate = _parseDate(first['created_at']);
      final secondDate = _parseDate(second['created_at']);

      if (firstDate == null && secondDate == null) return 0;
      if (firstDate == null) return 1;
      if (secondDate == null) return -1;
      return secondDate.compareTo(firstDate);
    });

    final unreadCount =
        _asInt(result['unread_count']) ??
        activities.where((activity) => !_asBool(activity['is_read'])).length;

    setState(() {
      _activities = activities;
      _isLoading = false;
      _loadError = null;
    });

    widget.onUnreadCountChanged?.call(unreadCount);
  }

  List<Map<String, dynamic>> get _actionRequiredActivities {
    return _activities.where(_isActionRequired).toList();
  }

  List<Map<String, dynamic>> get _updateActivities {
    return _activities
        .where((activity) => !_isActionRequired(activity))
        .toList();
  }

  bool _isActionRequired(Map<String, dynamic> activity) {
    final type = _cleanText(activity['type']).toLowerCase();
    final status = _cleanText(activity['status']).toLowerCase();
    final data = _asMap(activity['data']);
    final tab = _cleanText(data?['activity_tab']).toLowerCase();

    if (tab == 'action_required') return true;
    if (_asBool(data?['requires_action'])) return true;

    return type == 'plan_invitation' && status == 'pending';
  }

  int get _currentUnreadCount {
    return _activities
        .where((activity) => !_asBool(activity['is_read']))
        .length;
  }

  Future<void> _markAllActivityRead() async {
    if (_isMarkingAllRead || _currentUnreadCount == 0) return;

    setState(() {
      _isMarkingAllRead = true;
    });

    final result = await PlanService.markAllActivityRead();

    if (!mounted) return;

    setState(() {
      _isMarkingAllRead = false;
    });

    if (result['success'] != true) {
      _showMessage(
        _cleanText(result['message']).isNotEmpty
            ? _cleanText(result['message'])
            : 'Unable to mark activity as read.',
        isError: true,
      );
      return;
    }

    setState(() {
      _activities = _activities
          .map((activity) => <String, dynamic>{...activity, 'is_read': true})
          .toList();
    });

    widget.onUnreadCountChanged?.call(0);
  }

  Future<void> _markActivityReadIfNeeded(Map<String, dynamic> activity) async {
    if (_asBool(activity['is_read'])) return;

    final source = _cleanText(activity['source']);
    final sourceId = _asInt(activity['source_id']);
    if (sourceId == null) return;

    Map<String, dynamic> result;

    if (source == 'plan_invitation') {
      result = await PlanService.markPlanInvitationRead(invitationId: sourceId);
    } else if (source == 'activity_notification') {
      result = await PlanService.markActivityNotificationRead(
        notificationId: sourceId,
      );
    } else {
      return;
    }

    if (!mounted || result['success'] != true) return;

    final key = _activityKey(activity);
    setState(() {
      _activities = _activities.map((current) {
        if (_activityKey(current) != key) return current;
        return <String, dynamic>{...current, 'is_read': true};
      }).toList();
    });

    widget.onUnreadCountChanged?.call(_currentUnreadCount);
  }

  Future<void> _respondToInvitation({
    required Map<String, dynamic> activity,
    required String responseValue,
    BuildContext? sheetContext,
  }) async {
    final invitationId = _asInt(activity['source_id']);
    final activityKey = _activityKey(activity);

    if (invitationId == null || _processingActivityKeys.contains(activityKey)) {
      return;
    }

    setState(() {
      _processingActivityKeys.add(activityKey);
      _actionErrors.remove(activityKey);
    });

    final result = await PlanService.respondToPlanInvitation(
      invitationId: invitationId,
      responseValue: responseValue,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      final message = _cleanText(result['message']).isNotEmpty
          ? _cleanText(result['message'])
          : 'Unable to respond to this invitation.';

      setState(() {
        _processingActivityKeys.remove(activityKey);
        _actionErrors[activityKey] = message;
      });

      _showMessage(message, isError: true);
      return;
    }

    final responseInvitation = _asMap(result['invitation']);
    final responsePlan = _asMap(result['plan']);

    setState(() {
      _processingActivityKeys.remove(activityKey);
      _actionErrors.remove(activityKey);
      _activities = _activities.map((current) {
        if (_activityKey(current) != activityKey) return current;

        return <String, dynamic>{
          ...current,
          'status': responseValue,
          'is_read': true,
          if (responseInvitation?['plan'] is Map)
            'plan': Map<String, dynamic>.from(
              responseInvitation!['plan'] as Map,
            ),
          if (responsePlan != null) 'plan': responsePlan,
        };
      }).toList();
    });

    widget.onUnreadCountChanged?.call(_currentUnreadCount);

    if (responseValue == 'accepted') {
      widget.onPlanAccepted?.call();
    }

    if (sheetContext != null && sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }

    _showMessage(
      responseValue == 'accepted'
          ? 'Invitation accepted.'
          : 'Invitation declined.',
    );
  }

  Future<void> _respondToResponsibilityAssignment({
    required Map<String, dynamic> activity,
    required String responseValue,
    BuildContext? sheetContext,
    StateSetter? refreshSheet,
  }) async {
    final data = _asMap(activity['data']);
    final itemId = _asInt(data?['responsibility_item_id']);
    final activityKey = _activityKey(activity);

    if (itemId == null || _processingActivityKeys.contains(activityKey)) {
      return;
    }

    setState(() {
      _processingActivityKeys.add(activityKey);
      _actionErrors.remove(activityKey);
    });
    refreshSheet?.call(() {});

    final result = await PlanService.respondToResponsibility(
      itemId: itemId,
      responseValue: responseValue,
    );

    if (!mounted) return;

    if (result['success'] != true) {
      final message = _cleanText(result['message']).isNotEmpty
          ? _cleanText(result['message'])
          : 'Unable to respond to this assignment.';

      setState(() {
        _processingActivityKeys.remove(activityKey);
        _actionErrors[activityKey] = message;
      });
      refreshSheet?.call(() {});

      _showMessage(message, isError: true);
      return;
    }

    setState(() {
      _processingActivityKeys.remove(activityKey);
      _actionErrors.remove(activityKey);
      _activities = _activities.map((current) {
        if (_activityKey(current) != activityKey) return current;

        final currentData = _asMap(current['data']) ?? <String, dynamic>{};

        return <String, dynamic>{
          ...current,
          'type': responseValue == 'accepted'
              ? 'responsibility_assignment_accepted_by_you'
              : 'responsibility_assignment_declined_by_you',
          'is_read': true,
          'data': <String, dynamic>{
            ...currentData,
            'activity_tab': 'notifications',
            'requires_action': false,
            'resolution': responseValue,
          },
        };
      }).toList();
    });

    widget.onUnreadCountChanged?.call(_currentUnreadCount);
    refreshSheet?.call(() {});

    if (sheetContext != null && sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }

    _showMessage(
      responseValue == 'accepted'
          ? 'Assignment accepted.'
          : 'Assignment declined.',
    );
  }

  Future<void> _openResponsibilityReview(Map<String, dynamic> activity) async {
    await _markActivityReadIfNeeded(activity);
    if (!mounted) return;

    final activityKey = _activityKey(activity);
    final actorName = _actorName(activity);
    final planTitle = _planTitle(activity);
    final plan = _asMap(activity['plan']);
    final data = _asMap(activity['data']);
    final itemTitle = _responsibilityItemTitle(activity);
    final responsibilityTitle = _responsibilityTitle(activity);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final colors = theme.colorScheme;
            final isProcessing = _processingActivityKeys.contains(activityKey);
            final actionError = _actionErrors[activityKey];
            final stillRequiresAction = _asBool(data?['requires_action']);

            return Container(
              margin: const EdgeInsets.only(top: 48),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAvatar(
                          actorName,
                          icon: Icons.assignment_ind_rounded,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assignment Request',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$actorName assigned you to “$itemTitle” '
                                'in “$responsibilityTitle.”',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.55,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            responsibilityTitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(color: colors.outlineVariant, height: 1),
                          const SizedBox(height: 10),
                          Text(
                            '$planTitle • ${_planAvailabilityText(plan)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (actionError != null) ...[
                      const SizedBox(height: 14),
                      _buildInlineError(actionError),
                    ],
                    const SizedBox(height: 22),
                    if (stillRequiresAction)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isProcessing
                                  ? null
                                  : () => _respondToResponsibilityAssignment(
                                      activity: activity,
                                      responseValue: 'declined',
                                      sheetContext: sheetContext,
                                      refreshSheet: setSheetState,
                                    ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.onSurface,
                                side: BorderSide(color: colors.outlineVariant),
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: const Text(
                                'Decline',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: isProcessing
                                  ? null
                                  : () => _respondToResponsibilityAssignment(
                                      activity: activity,
                                      responseValue: 'accepted',
                                      sheetContext: sheetContext,
                                      refreshSheet: setSheetState,
                                    ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _brandYellow,
                                foregroundColor: Colors.black,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: isProcessing
                                  ? const SizedBox(
                                      width: 19,
                                      height: 19,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text(
                                      'Accept',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _openPlan(activity);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _brandYellow,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text(
                            'Open Plan',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openInvitationReview(Map<String, dynamic> activity) async {
    await _markActivityReadIfNeeded(activity);
    if (!mounted) return;

    final activityKey = _activityKey(activity);
    final actorName = _actorName(activity);
    final planTitle = _planTitle(activity);
    final plan = _asMap(activity['plan']);
    final status = _cleanText(activity['status']).toLowerCase();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final colors = theme.colorScheme;
            final isProcessing = _processingActivityKeys.contains(activityKey);
            final actionError = _actionErrors[activityKey];
            final isPending = status == 'pending';

            return Container(
              margin: const EdgeInsets.only(top: 48),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvatar(
                        actorName,
                        icon: Icons.person_add_alt_1_rounded,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plan Invitation',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$actorName invited you to join “$planTitle.”',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: 0.55,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          planTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _planAvailabilityText(plan),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (actionError != null) ...[
                    const SizedBox(height: 14),
                    _buildInlineError(actionError),
                  ],
                  const SizedBox(height: 22),
                  if (isPending)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isProcessing
                                ? null
                                : () async {
                                    setSheetState(() {});
                                    await _respondToInvitation(
                                      activity: activity,
                                      responseValue: 'declined',
                                      sheetContext: sheetContext,
                                    );
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.onSurface,
                              side: BorderSide(color: colors.outlineVariant),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            child: const Text(
                              'Decline',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: isProcessing
                                ? null
                                : () async {
                                    setSheetState(() {});
                                    await _respondToInvitation(
                                      activity: activity,
                                      responseValue: 'accepted',
                                      sheetContext: sheetContext,
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: _brandYellow,
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            child: isProcessing
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text(
                                    'Accept',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: status == 'accepted'
                            ? () {
                                Navigator.pop(sheetContext);
                                _openPlan(activity);
                              }
                            : () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: _brandYellow,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        icon: Icon(
                          status == 'accepted'
                              ? Icons.open_in_new_rounded
                              : Icons.close_rounded,
                        ),
                        label: Text(
                          status == 'accepted' ? 'Open Plan' : 'Close',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPlan(Map<String, dynamic> activity) async {
    if (!_canOpenPlanForActivity(activity)) {
      await _markActivityReadIfNeeded(activity);

      if (!mounted) return;

      final type = _cleanText(activity['type']).toLowerCase();
      _showMessage(
        type == 'member_removed'
            ? 'You no longer have access to this plan.'
            : 'This plan is no longer available.',
        isError: true,
      );
      return;
    }

    final plan = _asMap(activity['plan']);
    final planId = _asInt(plan?['id']);

    if (planId == null) {
      _showMessage('This plan is no longer available.', isError: true);
      return;
    }

    await _markActivityReadIfNeeded(activity);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanDashboardScreen(
          planId: planId,
          initialSection: _targetPlanSection(activity),
        ),
      ),
    );
  }

  String _activityKey(Map<String, dynamic> activity) {
    final key = _cleanText(activity['activity_key']);
    if (key.isNotEmpty) return key;
    return '${activity['source']}:${activity['source_id']}';
  }

  String _cleanText(dynamic value) => value?.toString().trim() ?? '';

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    return text == 'true' || text == '1';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _timeAgo(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return '';

    final difference = DateTime.now().difference(date);
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return '1d ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  String _sectionLabel(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return 'Earlier';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activityDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(activityDay).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return 'Earlier';
  }

  String _actorName(Map<String, dynamic> activity) {
    final actor = _asMap(activity['actor']);
    final name = _cleanText(actor?['name']);
    if (name.isNotEmpty) return name;

    final username = _cleanText(actor?['username']);
    if (username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }

    return 'DiNaDrawing';
  }

  String _planTitle(Map<String, dynamic> activity) {
    final title = _cleanText(_asMap(activity['plan'])?['title']);
    return title.isNotEmpty ? title : 'a plan';
  }

  String _responsibilityTitle(Map<String, dynamic> activity) {
    final data = _asMap(activity['data']);
    final title = _cleanText(data?['responsibility_title']);
    return title.isNotEmpty ? title : 'Who Does What';
  }

  String _responsibilityItemTitle(Map<String, dynamic> activity) {
    final data = _asMap(activity['data']);
    final title = _cleanText(data?['item_title']);
    return title.isNotEmpty ? title : 'this assignment';
  }

  String _commentPreview(Map<String, dynamic> activity) {
    return _cleanText(_asMap(activity['data'])?['comment_preview']);
  }

  String _planAvailabilityText(Map<String, dynamic>? plan) {
    if (plan == null) return 'Plan details are unavailable.';
    if (_asBool(plan['is_deleted'])) return 'This plan has been deleted.';
    if (_asBool(plan['is_archived'])) return 'This plan is currently archived.';

    final status = _cleanText(plan['status']);
    return status.isNotEmpty ? status : 'Active plan';
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              Expanded(child: _buildUnifiedActivity()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activity',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: colors.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Plan updates and pending tasks, organized by date.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (_currentUnreadCount > 0)
          TextButton(
            onPressed: _isMarkingAllRead ? null : _markAllActivityRead,
            child: _isMarkingAllRead
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Mark all read'),
          ),
        const SizedBox(width: 4),
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

  Widget _buildUnifiedActivity() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _brandYellow),
      );
    }

    if (_loadError != null && _activities.isEmpty) {
      return _buildErrorState();
    }

    final pendingTasks = _actionRequiredActivities;
    final notifications = _updateActivities;

    if (pendingTasks.isEmpty && notifications.isEmpty) {
      return RefreshIndicator(
        color: _brandYellow,
        onRefresh: () => _loadActivity(showLoading: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.56,
              child: _buildEmptyActivityState(),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];

    if (pendingTasks.isNotEmpty) {
      children.add(
        _buildSectionHeader(
          title: 'Pending Tasks',
          subtitle: 'Things that need your response',
          count: pendingTasks.length,
          icon: Icons.task_alt_rounded,
        ),
      );
      children.add(const SizedBox(height: 11));

      for (final activity in pendingTasks) {
        children.add(_buildActivityCard(activity));
        children.add(const SizedBox(height: 10));
      }

      children.add(const SizedBox(height: 18));
    }

    if (notifications.isNotEmpty) {
      String? previousSection;
      for (final activity in notifications) {
        final section = _sectionLabel(activity['created_at']);

        if (section != previousSection) {
          if (previousSection != null) {
            children.add(const SizedBox(height: 10));
          }

          children.add(
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                section,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
          previousSection = section;
        }

        children.add(_buildActivityCard(activity));
        children.add(const SizedBox(height: 10));
      }
    }

    children.add(const SizedBox(height: 100));

    return RefreshIndicator(
      color: _brandYellow,
      onRefresh: () => _loadActivity(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required int count,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _brandYellow.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: _brandYellowDark),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 27, minHeight: 27),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final type = _cleanText(activity['type']).toLowerCase();

    if (type == 'plan_invitation') {
      return _buildInvitationCard(activity);
    }

    if (type == 'post_comment') {
      return _buildCommentCard(activity);
    }

    if (type == 'responsibility_assignment_pending') {
      return _buildResponsibilityAssignmentCard(activity);
    }

    return _buildGenericCard(activity);
  }

  Widget _buildInvitationCard(Map<String, dynamic> activity) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activityKey = _activityKey(activity);
    final status = _cleanText(activity['status']).toLowerCase();
    final isPending = status == 'pending';
    final isUnread = !_asBool(activity['is_read']);
    final isProcessing = _processingActivityKeys.contains(activityKey);
    final actorName = _actorName(activity);
    final planTitle = _planTitle(activity);
    final actionError = _actionErrors[activityKey];

    final message = isPending
        ? '$actorName invited you to join “$planTitle.”'
        : status == 'accepted'
        ? 'You accepted the invitation to “$planTitle.”'
        : 'You declined the invitation to “$planTitle.”';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => isPending
            ? _openInvitationReview(activity)
            : status == 'accepted'
            ? _openPlan(activity)
            : _markActivityReadIfNeeded(activity),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(colors: colors),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(
                actorName,
                icon: isPending
                    ? Icons.person_add_alt_1_rounded
                    : status == 'accepted'
                    ? Icons.check_rounded
                    : Icons.close_rounded,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface,
                              height: 1.42,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: _brandYellowDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _timeAgo(activity['created_at']),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 13),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () => _openInvitationReview(activity),
                          style: FilledButton.styleFrom(
                            backgroundColor: _brandYellow,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          icon: isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(
                                  Icons.mail_outline_rounded,
                                  size: 18,
                                ),
                          label: const Text(
                            'Review Invite',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ] else if (status == 'accepted') ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _openPlan(activity),
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: const Text('Open Plan'),
                          style: TextButton.styleFrom(
                            foregroundColor: _brandYellowDark,
                          ),
                        ),
                      ),
                    ],
                    if (actionError != null) ...[
                      const SizedBox(height: 10),
                      _buildInlineError(actionError),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsibilityAssignmentCard(Map<String, dynamic> activity) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final activityKey = _activityKey(activity);
    final isUnread = !_asBool(activity['is_read']);
    final isProcessing = _processingActivityKeys.contains(activityKey);
    final actorName = _actorName(activity);
    final itemTitle = _responsibilityItemTitle(activity);
    final responsibilityTitle = _responsibilityTitle(activity);
    final actionError = _actionErrors[activityKey];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openResponsibilityReview(activity),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(colors: colors),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(actorName, icon: Icons.assignment_ind_rounded),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '$actorName assigned you to “$itemTitle” '
                            'in “$responsibilityTitle.”',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface,
                              height: 1.42,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: _brandYellowDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _timeAgo(activity['created_at']),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: isProcessing
                            ? null
                            : () => _openResponsibilityReview(activity),
                        style: FilledButton.styleFrom(
                          backgroundColor: _brandYellow,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        icon: isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.fact_check_outlined, size: 18),
                        label: const Text(
                          'Review Assignment',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    if (actionError != null) ...[
                      const SizedBox(height: 10),
                      _buildInlineError(actionError),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> activity) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final actorName = _actorName(activity);
    final planTitle = _planTitle(activity);
    final preview = _commentPreview(activity);
    final isUnread = !_asBool(activity['is_read']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPlan(activity),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(colors: colors),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(actorName, icon: Icons.chat_bubble_rounded),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '$actorName commented on your post in “$planTitle.”',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface,
                              height: 1.42,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: _brandYellowDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          '“$preview”',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          _timeAgo(activity['created_at']),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'View Plan',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _brandYellowDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: _brandYellowDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenericCard(Map<String, dynamic> activity) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final actorName = _actorName(activity);
    final planTitle = _planTitle(activity);
    final data = _asMap(activity['data']);
    final suppliedMessage = _cleanText(data?['message']);
    final type = _cleanText(activity['type']).toLowerCase();
    final isUnread = !_asBool(activity['is_read']);
    final canOpenPlan = _canOpenPlanForActivity(activity);
    final actionLabel = _actionLabelForActivity(activity);
    final icon = _genericActivityIcon(type);

    final message = suppliedMessage.isNotEmpty
        ? suppliedMessage
        : _genericMessage(
            type: type,
            actorName: actorName,
            planTitle: planTitle,
            data: data,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (canOpenPlan) {
            _openPlan(activity);
          } else {
            _markActivityReadIfNeeded(activity);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(colors: colors),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(actorName, icon: icon),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface,
                              height: 1.42,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: _brandYellowDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          _timeAgo(activity['created_at']),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (canOpenPlan) ...[
                          const Spacer(),
                          Text(
                            actionLabel ?? 'View Plan',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: _brandYellowDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: _brandYellowDark,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canOpenPlanForActivity(Map<String, dynamic> activity) {
    final type = _cleanText(activity['type']).toLowerCase();
    final plan = _asMap(activity['plan']);

    if (type == 'member_removed' || type == 'plan_deleted') {
      return false;
    }

    if (plan == null || _asInt(plan['id']) == null) {
      return false;
    }

    return !_asBool(plan['is_deleted']);
  }

  String _targetPlanSection(Map<String, dynamic> activity) {
    final type = _cleanText(activity['type']).toLowerCase();

    if (type.startsWith('budget_')) {
      return 'budget';
    }

    return 'feed';
  }

  String? _actionLabelForActivity(Map<String, dynamic> activity) {
    final type = _cleanText(activity['type']).toLowerCase();
    final data = _asMap(activity['data']);
    final action = _cleanText(data?['action']).toLowerCase();

    if (action == 'vote') return 'Vote Now';
    if (action == 'review_vote') return 'Review Vote';
    if (action == 'review_payment') return 'Review Payment';
    if (action == 'settle_up') return 'Settle Up';
    if (action == 'review_budget') return 'Review Budget';
    if (action == 'post_event_check') return 'Review Plan';

    if (type.startsWith('poll_')) return 'View Poll';
    if (type.startsWith('responsibility_')) return 'View Responsibility';
    if (type.startsWith('budget_')) return 'View Budget';

    return null;
  }

  IconData _genericActivityIcon(String type) {
    switch (type) {
      case 'invitation_accepted':
        return Icons.how_to_reg_rounded;
      case 'invitation_declined':
        return Icons.person_off_rounded;
      case 'member_joined':
        return Icons.group_add_rounded;
      case 'member_left':
        return Icons.logout_rounded;
      case 'member_removed':
        return Icons.person_remove_rounded;
      case 'admin_transferred':
        return Icons.admin_panel_settings_rounded;
      case 'responsibility_assignment_pending':
      case 'responsibility_direct_assigned':
      case 'responsibility_item_added':
        return Icons.assignment_ind_rounded;
      case 'responsibility_assignment_accepted_by_you':
      case 'responsibility_assignment_accepted':
      case 'responsibility_finalized':
        return Icons.task_alt_rounded;
      case 'responsibility_assignment_declined_by_you':
      case 'responsibility_assignment_declined':
      case 'responsibility_assignment_removed':
        return Icons.assignment_late_outlined;
      case 'responsibility_claimed':
        return Icons.pan_tool_alt_rounded;
      case 'responsibility_unclaimed':
        return Icons.person_remove_alt_1_rounded;
      case 'responsibility_progress_updated':
      case 'responsibility_progress_updated_by_you':
      case 'responsibility_updated':
        return Icons.trending_up_rounded;
      case 'poll_vote_required':
      case 'poll_vote_review_required':
      case 'poll_voting_ending_soon':
        return Icons.how_to_vote_rounded;
      case 'poll_votes_received':
        return Icons.bar_chart_rounded;
      case 'poll_finalized':
        return Icons.emoji_events_rounded;
      case 'poll_voting_closed':
        return Icons.lock_clock_rounded;
      case 'poll_scheduled':
        return Icons.schedule_rounded;
      case 'budget_contribution_required':
      case 'budget_contribution_changed':
      case 'budget_allocation_assigned':
      case 'budget_allocation_changed':
      case 'budget_payment_rejected':
        return Icons.payments_outlined;
      case 'budget_payment_submitted':
        return Icons.receipt_long_rounded;
      case 'budget_payment_verified':
      case 'budget_all_settled':
        return Icons.verified_rounded;
      case 'budget_review_required':
        return Icons.rule_folder_outlined;
      case 'plan_date_changed':
      case 'plan_time_changed':
      case 'plan_schedule_changed':
      case 'plan_rescheduled':
      case 'plan_happening_tomorrow':
      case 'plan_happening_soon':
        return Icons.event_rounded;
      case 'plan_location_changed':
        return Icons.location_on_rounded;
      case 'plan_cancelled':
      case 'plan_postponed':
        return Icons.event_busy_rounded;
      case 'plan_archived':
      case 'plan_completed_archived':
        return Icons.archive_rounded;
      case 'plan_restored':
      case 'plan_restored_from_archive':
        return Icons.unarchive_rounded;
      case 'plan_deleted':
        return Icons.delete_outline_rounded;
      case 'plan_completed':
        return Icons.check_circle_rounded;
      case 'post_event_check_required':
        return Icons.fact_check_outlined;
      case 'account_password_changed':
        return Icons.lock_reset_rounded;
      case 'account_email_verified':
        return Icons.mark_email_read_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _genericMessage({
    required String type,
    required String actorName,
    required String planTitle,
    Map<String, dynamic>? data,
  }) {
    final itemTitle = _cleanText(data?['item_title']).isNotEmpty
        ? _cleanText(data?['item_title'])
        : 'this assignment';
    final responsibilityTitle =
        _cleanText(data?['responsibility_title']).isNotEmpty
        ? _cleanText(data?['responsibility_title'])
        : 'Who Does What';
    final pollQuestion = _cleanText(data?['poll_question']).isNotEmpty
        ? _cleanText(data?['poll_question'])
        : 'the poll';
    final winningOption = _cleanText(data?['winning_option']);
    final newValue = _cleanText(data?['new_value']);
    final amount = _asDouble(data?['amount']);
    final amountText = amount == null ? '' : '₱${amount.toStringAsFixed(2)}';
    final voteCount = _asInt(data?['vote_count']) ?? 0;
    final minutesRemaining = _asInt(data?['minutes_remaining']);

    switch (type) {
      case 'invitation_accepted':
        return '$actorName accepted your invitation to “$planTitle.”';
      case 'invitation_declined':
        return '$actorName declined your invitation to “$planTitle.”';
      case 'member_joined':
        return '$actorName joined “$planTitle.”';
      case 'member_left':
        return '$actorName left “$planTitle.”';
      case 'member_removed':
        return 'You were removed from “$planTitle” by $actorName.';
      case 'admin_transferred':
        return '$actorName transferred admin ownership of “$planTitle” to you.';
      case 'responsibility_assignment_accepted_by_you':
        return 'You accepted “$itemTitle” in “$responsibilityTitle.”';
      case 'responsibility_assignment_declined_by_you':
        return 'You declined “$itemTitle” in “$responsibilityTitle.”';
      case 'responsibility_assignment_removed':
        return '$actorName removed your assignment to “$itemTitle” '
            'in “$responsibilityTitle.”';
      case 'responsibility_assignment_accepted':
        return '$actorName accepted “$itemTitle” in “$responsibilityTitle.”';
      case 'responsibility_assignment_declined':
        return '$actorName declined “$itemTitle” in “$responsibilityTitle.”';
      case 'responsibility_assignment_pending':
        return '$actorName assigned you to “$itemTitle” in “$responsibilityTitle.”';
      case 'responsibility_direct_assigned':
        return 'You were assigned to “$itemTitle” in “$responsibilityTitle.”';
      case 'responsibility_progress_updated_by_you':
        return 'You updated your contribution in “$responsibilityTitle.”';
      case 'responsibility_claimed':
        return '$actorName claimed “$itemTitle” in “$responsibilityTitle.”';
      case 'responsibility_unclaimed':
        return '$actorName left “$itemTitle” unassigned in “$responsibilityTitle.”';
      case 'responsibility_item_added':
        return '$actorName added “$itemTitle” to “$responsibilityTitle.”';
      case 'responsibility_updated':
        return '“$responsibilityTitle” was updated.';
      case 'responsibility_progress_updated':
        return '$actorName updated their progress on “$itemTitle.”';
      case 'responsibility_finalized':
        return '“$responsibilityTitle” has been finalized.';
      case 'responsibility_reopened':
        return '“$responsibilityTitle” was reopened.';
      case 'poll_vote_required':
        return 'A new poll was posted in “$planTitle”: “$pollQuestion.”';
      case 'poll_vote_review_required':
        return 'A new option was added to “$pollQuestion.” Review your vote.';
      case 'poll_voting_ending_soon':
        return minutesRemaining == null
            ? 'Voting for “$pollQuestion” is ending soon.'
            : 'Voting for “$pollQuestion” ends in about $minutesRemaining minutes.';
      case 'poll_scheduled':
        return 'A poll was scheduled in “$planTitle”: “$pollQuestion.”';
      case 'poll_votes_received':
        return '$voteCount ${voteCount == 1 ? 'vote was' : 'votes were'} submitted to “$pollQuestion.”';
      case 'poll_voting_closed':
        return 'Voting has ended for “$pollQuestion.”';
      case 'poll_finalized':
        return winningOption.isEmpty
            ? 'The result for “$pollQuestion” was finalized.'
            : '“$winningOption” won the poll in “$planTitle.”';
      case 'budget_contribution_required':
        return amountText.isEmpty
            ? 'A contribution request was added to “$planTitle.”'
            : 'You need to contribute $amountText for “$planTitle.”';
      case 'budget_contribution_changed':
        return 'Your contribution for “$planTitle” was changed to $amountText.';
      case 'budget_allocation_assigned':
        return amountText.isEmpty
            ? 'You were included in the budget for “$planTitle.”'
            : '$amountText was assigned to you in the budget for “$planTitle.”';
      case 'budget_allocation_changed':
        return 'Your budget share for “$planTitle” was changed to $amountText.';
      case 'budget_payment_submitted':
        return '$actorName marked their $amountText contribution as paid.';
      case 'budget_payment_verified':
        return 'Your $amountText contribution for “$planTitle” was verified.';
      case 'budget_payment_rejected':
        return 'Your $amountText contribution for “$planTitle” needs attention.';
      case 'budget_all_settled':
        return 'All contributions for “$planTitle” are settled.';
      case 'budget_review_required':
        return 'The budget for “$planTitle” needs review after a member change.';
      case 'plan_date_changed':
        return newValue.isNotEmpty
            ? 'The date for “$planTitle” was changed to $newValue.'
            : 'The date for “$planTitle” was updated.';
      case 'plan_time_changed':
        return 'The time for “$planTitle” was updated.';
      case 'plan_schedule_changed':
        return 'The schedule for “$planTitle” was updated.';
      case 'plan_location_changed':
        return newValue.isNotEmpty
            ? 'The location for “$planTitle” was changed to $newValue.'
            : 'The location for “$planTitle” was updated.';
      case 'plan_description_changed':
      case 'plan_details_changed':
        return 'Important details in “$planTitle” were updated.';
      case 'plan_happening_tomorrow':
        return '“$planTitle” is happening tomorrow.';
      case 'plan_happening_soon':
        return minutesRemaining == null
            ? '“$planTitle” is starting soon.'
            : '“$planTitle” starts in about $minutesRemaining minutes.';
      case 'plan_cancelled':
        return '“$planTitle” was cancelled.';
      case 'plan_postponed':
        return '“$planTitle” was postponed.';
      case 'plan_rescheduled':
        return '“$planTitle” was rescheduled.';
      case 'plan_completed':
        return '“$planTitle” was marked as completed.';
      case 'plan_completed_archived':
        return '“$planTitle” was completed and archived.';
      case 'plan_archived':
        return '“$planTitle” was archived.';
      case 'plan_restored_from_archive':
      case 'plan_restored':
        return '“$planTitle” was restored.';
      case 'plan_deleted':
        return '“$planTitle” was deleted.';
      case 'post_event_check_required':
        return 'Did “$planTitle” happen? Update the plan status.';
      case 'account_password_changed':
        return 'Your password was changed successfully.';
      case 'account_email_verified':
        return 'Your email has been verified.';
      default:
        return '$actorName updated “$planTitle.”';
    }
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  BoxDecoration _cardDecoration({required ColorScheme colors}) {
    return BoxDecoration(
      color: colors.surface,
      border: Border.all(color: colors.outlineVariant),
      borderRadius: BorderRadius.circular(16),
    );
  }

  Widget _buildAvatar(String name, {required IconData icon}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _brandYellow.withValues(alpha: 0.18),
          child: Text(
            _initials(name),
            style: const TextStyle(
              color: _brandYellowDark,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              color: _brandYellow,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
            child: Icon(icon, size: 10, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineError(String message) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 16, color: colors.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return RefreshIndicator(
      color: _brandYellow,
      onRefresh: () => _loadActivity(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.52,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 46,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadActivity,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: TextButton.styleFrom(
                      foregroundColor: _brandYellowDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityState() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _brandYellow.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: _brandYellowDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You’re all caught up',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pending tasks and new plan notifications will appear here.',
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
}
