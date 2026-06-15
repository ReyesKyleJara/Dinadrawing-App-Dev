import 'package:flutter/material.dart';

import '../../navigation/main_wrapper.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() {
    return _ActivityScreenState();
  }
}

class _ActivityScreenState extends State<ActivityScreen> {
  // 0 = Notifications
  // 1 = Pending Tasks
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();

    _loadCurrentUserProfile();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildCustomTabBar(),
              const SizedBox(height: 24),

              if (_selectedTabIndex == 0)
                _buildNotificationsList()
              else
                _buildPendingTasksList(),

              // Space for the bottom navigation bar.
              const SizedBox(height: 100),
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
                builder: (_) => const MainWrapper(initialIndex: 3),
              ),
            );
          },
          child: const ProfileAvatar(radius: 19),
        ),
      ],
    );
  }

  Widget _buildCustomTabBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = 0;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0
                      ? const Color(0xFFF2B73F)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    fontWeight: _selectedTabIndex == 0
                        ? FontWeight.bold
                        : FontWeight.w500,
                    fontSize: 13,
                    color: _selectedTabIndex == 0
                        ? Colors.black
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = 1;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1
                      ? const Color(0xFFF2B73F)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Pending Tasks',
                  style: TextStyle(
                    fontWeight: _selectedTabIndex == 1
                        ? FontWeight.bold
                        : FontWeight.w500,
                    fontSize: 13,
                    color: _selectedTabIndex == 1
                        ? Colors.black
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today',
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 12),
        _buildNotificationCard(
          avatarPath: 'images/avatar_female.png',
          isUnread: true,
          time: '10 minutes ago',
          content: _notificationText(
            children: const [
              TextSpan(
                text: 'Jara ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'voted '),
              TextSpan(
                text: 'Yes ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'to '),
              TextSpan(
                text: '"Are you going?" ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'poll in '),
              TextSpan(
                text: 'Capstone Planning.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildNotificationCard(
          avatarPath: 'images/avatar_male.png',
          isUnread: false,
          time: '3 hours ago',
          showAvatarStack: true,
          avatarStackText: '4/6 votes',
          content: _notificationText(
            children: const [
              TextSpan(
                text: 'Janril ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'voted for the poll you posted in '),
              TextSpan(
                text: 'Birthday ni Kenny.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Yesterday',
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 12),
        _buildNotificationCard(
          avatarPath: 'images/avatar_female.png',
          isUnread: false,
          time: '1d ago',
          content: _notificationText(
            children: const [
              TextSpan(
                text: 'You ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'joined the '),
              TextSpan(
                text: 'Dinadrawing Presentation.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildNotificationCard(
          avatarPath: 'images/avatar_female2.png',
          isUnread: false,
          time: '1d ago',
          content: _notificationText(
            children: const [
              TextSpan(
                text: 'Venice ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'assigned you to '),
              TextSpan(
                text: 'write Objectives part ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'task in '),
              TextSpan(
                text: 'Capstone Planning.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingTasksList() {
    return Column(
      children: [
        _buildTaskCard(
          avatarPath: 'images/avatar_female.png',
          actionText: 'Settle Up',
          actionColor: const Color(0xFFF2B73F),
          content: _notificationText(
            children: const [
              TextSpan(
                text: 'Settle Up ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'Contributions for '),
              TextSpan(
                text: 'Capstone Planning.\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: 'Josh requests 350 PHP for Contributions.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTaskCard(
          avatarPath: 'images/avatar_male.png',
          actionText: 'Vote',
          actionColor: const Color(0xFFF2B73F),
          showAvatarStack: true,
          avatarStackText: '4/8 votes',
          content: _notificationText(
            children: const [
              TextSpan(
                text: '[4/8] ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'Vote on '),
              TextSpan(
                text: 'Ramen House ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'for '),
              TextSpan(
                text: 'Dinner sa Japan lang.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTaskCard(
          avatarPath: 'images/avatar_male.png',
          actionText: 'Vote',
          actionColor: const Color(0xFFF2B73F),
          showAvatarStack: true,
          avatarStackText: '3/8 votes',
          content: _notificationText(
            children: const [
              TextSpan(
                text: '[3/8] ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'Vote on '),
              TextSpan(
                text: 'Ramen House ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'for '),
              TextSpan(
                text: 'Dinner sa Japan lang.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTaskCard(
          avatarPath: 'images/avatar_female.png',
          actionText: 'Settle Up',
          actionColor: const Color(0xFFF2B73F),
          content: _notificationText(
            children: const [
              TextSpan(
                text: 'Settle Up ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'Contributions for '),
              TextSpan(
                text: 'Capstone Planning.\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: 'Josh requests 10,350 PHP for Contributions.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  RichText _notificationText({required List<InlineSpan> children}) {
    final colorScheme = Theme.of(context).colorScheme;

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurface,
          height: 1.4,
        ),
        children: children,
      ),
    );
  }

  Widget _buildNotificationCard({
    required String avatarPath,
    required bool isUnread,
    required RichText content,
    required String time,
    bool showAvatarStack = false,
    String? avatarStackText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFFFFF7E6) : colorScheme.surface,
        border: Border.all(
          color: isUnread
              ? const Color(0xFFF2B73F)
              : colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.surfaceContainerHighest,
            backgroundImage: AssetImage(avatarPath),
            onBackgroundImageError: (_, _) {},
            child: Icon(Icons.person, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                if (showAvatarStack) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildAvatarStack(4),
                      const SizedBox(width: 8),
                      Text(
                        avatarStackText ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard({
    required String avatarPath,
    required RichText content,
    required String actionText,
    required Color actionColor,
    bool showAvatarStack = false,
    String? avatarStackText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.surfaceContainerHighest,
            backgroundImage: AssetImage(avatarPath),
            onBackgroundImageError: (_, _) {},
            child: Icon(Icons.person, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (showAvatarStack)
                      Row(
                        children: [
                          _buildAvatarStack(3),
                          const SizedBox(width: 8),
                          Text(
                            avatarStackText ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionColor,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        actionText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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

  Widget _buildAvatarStack(int count) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 24 + (16 * (count - 1)),
      height: 24,
      child: Stack(
        children: List.generate(count, (index) {
          return Positioned(
            left: index * 16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.blueGrey,
                child: Icon(Icons.person, size: 12, color: Colors.white),
              ),
            ),
          );
        }),
      ),
    );
  }
}
