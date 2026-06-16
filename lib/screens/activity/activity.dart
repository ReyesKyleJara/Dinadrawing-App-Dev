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
  State<ActivityScreen> createState() {
    return _ActivityScreenState();
  }
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const Color _brandYellow = Color(0xFFF2B73F);
  static const Color _brandYellowDark = Color(0xFFD89B22);

  bool _isLoading = true;
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

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _isLoading = false;
        _loadError = result['message']?.toString().trim().isNotEmpty == true
            ? result['message'].toString().trim()
            : 'Unable to load activity.';
      });

      return;
    }

    final rawActivities = result['activities'];

    final activities = rawActivities is List
        ? rawActivities
              .whereType<Map>()
              .map((activity) => Map<String, dynamic>.from(activity))
              .toList()
        : <Map<String, dynamic>>[];

    activities.sort((first, second) {
      final firstDate = _parseDate(first['created_at']);

      final secondDate = _parseDate(second['created_at']);

      if (firstDate == null && secondDate == null) {
        return 0;
      }

      if (firstDate == null) {
        return 1;
      }

      if (secondDate == null) {
        return -1;
      }

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

    if (unreadCount > 0) {
      _markAllActivityRead();
    }
  }

  Future<void> _markAllActivityRead() async {
    final result = await PlanService.markAllActivityRead();

    if (!mounted || result['success'] != true) {
      return;
    }

    widget.onUnreadCountChanged?.call(0);
  }

  Future<void> _respondToInvitation({
    required Map<String, dynamic> activity,
    required String responseValue,
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

    if (!mounted) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _processingActivityKeys.remove(activityKey);

        _actionErrors[activityKey] =
            result['message']?.toString().trim().isNotEmpty == true
            ? result['message'].toString().trim()
            : 'Unable to respond to this invitation.';
      });

      return;
    }

    setState(() {
      _processingActivityKeys.remove(activityKey);

      _actionErrors.remove(activityKey);

      _activities = _activities.map((current) {
        if (_activityKey(current) != activityKey) {
          return current;
        }

        return {...current, 'status': responseValue, 'is_read': true};
      }).toList();
    });

    widget.onUnreadCountChanged?.call(0);

    if (responseValue == 'accepted') {
      widget.onPlanAccepted?.call();
    }
  }

  Future<void> _openCommentActivity(Map<String, dynamic> activity) async {
    final plan = _asMap(activity['plan']);

    final planId = _asInt(plan?['id']);

    if (planId == null) {
      _showMessage('This plan is no longer available.', isError: true);

      return;
    }

    await _markGenericActivityReadIfNeeded(activity);

    if (!mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return PlanDashboardScreen(planId: planId);
        },
      ),
    );
  }

  Future<void> _markGenericActivityReadIfNeeded(
    Map<String, dynamic> activity,
  ) async {
    if (_asBool(activity['is_read'])) {
      return;
    }

    if (activity['source']?.toString() != 'activity_notification') {
      return;
    }

    final notificationId = _asInt(activity['source_id']);

    if (notificationId == null) {
      return;
    }

    final result = await PlanService.markActivityNotificationRead(
      notificationId: notificationId,
    );

    if (!mounted || result['success'] != true) {
      return;
    }

    final key = _activityKey(activity);

    setState(() {
      _activities = _activities.map((current) {
        if (_activityKey(current) != key) {
          return current;
        }

        return {...current, 'is_read': true};
      }).toList();
    });

    widget.onUnreadCountChanged?.call(_currentUnreadCount);
  }

  int get _currentUnreadCount {
    return _activities
        .where((activity) => !_asBool(activity['is_read']))
        .length;
  }

  String _activityKey(Map<String, dynamic> activity) {
    final key = activity['activity_key']?.toString().trim();

    if (key != null && key.isNotEmpty) {
      return key;
    }

    return '${activity['source']}:'
        '${activity['source_id']}';
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value == null) {
      return fallback;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text = value.toString().trim().toLowerCase();

    return text == 'true' || text == '1';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _timeAgo(dynamic value) {
    final date = _parseDate(value);

    if (date == null) {
      return '';
    }

    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays == 1) {
      return '1d ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${date.month}/'
        '${date.day}/'
        '${date.year}';
  }

  String _sectionLabel(dynamic value) {
    final date = _parseDate(value);

    if (date == null) {
      return 'Earlier';
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final activityDay = DateTime(date.year, date.month, date.day);

    final difference = today.difference(activityDay).inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    return 'Earlier';
  }

  String _actorName(Map<String, dynamic> activity) {
    final actor = _asMap(activity['actor']);

    final name = actor?['name']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final username = actor?['username']?.toString().trim();

    if (username != null && username.isNotEmpty) {
      return username.startsWith('@') ? username : '@$username';
    }

    return 'Someone';
  }

  String _planTitle(Map<String, dynamic> activity) {
    final plan = _asMap(activity['plan']);

    final title = plan?['title']?.toString().trim();

    if (title != null && title.isNotEmpty) {
      return title;
    }

    return 'a plan';
  }

  String _commentPreview(Map<String, dynamic> activity) {
    final data = _asMap(activity['data']);

    final preview = data?['comment_preview']?.toString().trim();

    if (preview != null && preview.isNotEmpty) {
      return preview;
    }

    return '';
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}'
            '${parts.last[0]}'
        .toUpperCase();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              Text(
                'Recent Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(child: _buildActivityView()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Activity',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) {
                  return const MainWrapper(initialIndex: 3);
                },
              ),
            );
          },
          child: const ProfileAvatar(radius: 19),
        ),
      ],
    );
  }

  Widget _buildActivityView() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _brandYellow),
      );
    }

    if (_loadError != null && _activities.isEmpty) {
      return _buildErrorState();
    }

    if (_activities.isEmpty) {
      return RefreshIndicator(
        color: _brandYellow,
        onRefresh: () {
          return _loadActivity(showLoading: false);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.52,
              child: _buildEmptyState(),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];
    String? previousSection;

    for (final activity in _activities) {
      final section = _sectionLabel(activity['created_at']);

      if (section != previousSection) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: 22));
        }

        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              section,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );

        previousSection = section;
      }

      children.add(_buildActivityCard(activity));

      children.add(const SizedBox(height: 12));
    }

    children.add(const SizedBox(height: 100));

    return RefreshIndicator(
      color: _brandYellow,
      onRefresh: () {
        return _loadActivity(showLoading: false);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final type = activity['type']?.toString().trim().toLowerCase() ?? '';

    if (type == 'plan_invitation') {
      return _buildInvitationCard(activity);
    }

    if (type == 'post_comment') {
      return _buildCommentCard(activity);
    }

    return _buildGenericCard(activity);
  }

  Widget _buildInvitationCard(Map<String, dynamic> activity) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final activityKey = _activityKey(activity);

    final status =
        activity['status']?.toString().trim().toLowerCase() ?? 'pending';

    final isUnread = !_asBool(activity['is_read']);

    final isProcessing = _processingActivityKeys.contains(activityKey);

    final actorName = _actorName(activity);

    final planTitle = _planTitle(activity);

    final actionError = _actionErrors[activityKey];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(
        colors: colors,
        isUnread: isUnread,
        theme: theme,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(actorName, icon: Icons.person_add_alt_1_rounded),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      height: 1.42,
                    ),
                    children: [
                      TextSpan(
                        text: actorName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const TextSpan(text: ' invited you to join '),
                      TextSpan(
                        text: planTitle,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _timeAgo(activity['created_at']),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
                if (status == 'pending') ...[
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isProcessing
                              ? null
                              : () {
                                  _respondToInvitation(
                                    activity: activity,
                                    responseValue: 'declined',
                                  );
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.onSurface,
                            side: BorderSide(color: colors.outlineVariant),
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isProcessing
                              ? null
                              : () {
                                  _respondToInvitation(
                                    activity: activity,
                                    responseValue: 'accepted',
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandYellow,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor:
                                colors.surfaceContainerHighest,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  'Accept',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  _buildStatusChip(accepted: status == 'accepted'),
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
        onTap: () {
          _openCommentActivity(activity);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(
            colors: colors,
            isUnread: isUnread,
            theme: theme,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(actorName, icon: Icons.chat_bubble_rounded),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                          height: 1.42,
                        ),
                        children: [
                          TextSpan(
                            text: actorName,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const TextSpan(text: ' commented on your post in '),
                          TextSpan(
                            text: planTitle,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
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
                            fontSize: 11.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'View post',
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(
        colors: colors,
        isUnread: !_asBool(activity['is_read']),
        theme: theme,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(actorName, icon: Icons.notifications_rounded),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$actorName updated '
                  '$planTitle.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _timeAgo(activity['created_at']),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({
    required ColorScheme colors,
    required bool isUnread,
    required ThemeData theme,
  }) {
    return BoxDecoration(
      color: isUnread
          ? theme.brightness == Brightness.dark
                ? _brandYellow.withValues(alpha: 0.10)
                : const Color(0xFFFFF7E6)
          : colors.surface,
      border: Border.all(
        color: isUnread ? _brandYellow : colors.outlineVariant,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.12 : 0.025,
          ),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
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

  Widget _buildStatusChip({required bool accepted}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final backgroundColor = accepted
        ? Colors.green.withValues(alpha: 0.13)
        : colors.surfaceContainerHighest;

    final foregroundColor = accepted
        ? Colors.green.shade700
        : colors.onSurfaceVariant;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              accepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 15,
              color: foregroundColor,
            ),
            const SizedBox(width: 5),
            Text(
              accepted ? 'Accepted' : 'Declined',
              style: theme.textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
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
      onRefresh: () {
        return _loadActivity(showLoading: false);
      },
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

  Widget _buildEmptyState() {
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
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: _brandYellowDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Invitations, comments, assignments, '
            'and plan updates will appear here.',
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
