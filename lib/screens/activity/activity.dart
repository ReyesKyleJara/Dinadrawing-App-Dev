import 'package:flutter/material.dart';
import '../../navigation/main_wrapper.dart';
import '../../services/profile_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // 0 = Notifications, 1 = Pending Tasks
  int _selectedTabIndex = 0;

  TextStyle get _cardTextStyle => TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
        height: 1.4,
      );

  TextStyle get _mutedTextStyle => TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildCustomTabBar(),
              const SizedBox(height: 24),
              
              // Switch between content based on selected tab
              _selectedTabIndex == 0 
                  ? _buildNotificationsList() 
                  : _buildPendingTasksList(),
                  
              const SizedBox(height: 100), // Space for bottom nav
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
        Text(
          'Activity',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        // Shared clickable avatar (reflects ProfileService)
        ClipOval(
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MainWrapper(initialIndex: 3))),
            child: AnimatedBuilder(
              animation: Listenable.merge([
                ProfileService.instance.avatarBytes,
                ProfileService.instance.avatarIcon,
              ]),
              builder: (context, _) {
                final bytes = ProfileService.instance.avatarBytes.value;
                final icon = ProfileService.instance.avatarIcon.value;

                if (bytes != null) {
                  return CircleAvatar(radius: 19, backgroundImage: MemoryImage(bytes));
                }
                if (icon != null) {
                  return CircleAvatar(radius: 19, backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface));
                }

                return CircleAvatar(
                  radius: 19,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildCustomTabBar() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? const Color(0xFFF2B73F) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                    color: _selectedTabIndex == 0 ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? const Color(0xFFF2B73F) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Pending Tasks',
                  style: TextStyle(
                    fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                    color: _selectedTabIndex == 1 ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Today', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        _buildNotificationCard(
          avatarPath: 'images/avatar_female.png', 
          isUnread: true,
          time: '10 minutes ago',
          content: RichText(
            text: TextSpan(
              style: _cardTextStyle,
              children: const [
                TextSpan(text: 'Jara ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'voted '),
                TextSpan(text: 'Yes ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'to '),
                TextSpan(text: '"Are you going?" ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'poll in '),
                TextSpan(text: 'Capstone Planning.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildNotificationCard(
          avatarPath: 'images/avatar_male.png',
          isUnread: false,
          time: '3 hours ago',
          showAvatarStack: true,
          avatarStackText: '4/6 votes',
          content: RichText(
            text: TextSpan(
              style: _cardTextStyle,
              children: [
                TextSpan(text: 'Janril ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'voted for the poll you posted in '),
                TextSpan(text: 'Birthday ni Kenny.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        Text('Yesterday', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        
        _buildNotificationCard(
          avatarPath: 'images/avatar_female.png',
          isUnread: false,
          time: '1d ago',
          content: RichText(
            text: TextSpan(
              style: _cardTextStyle,
              children: [
                TextSpan(text: 'You ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'joined the '),
                TextSpan(text: 'Dinadrawing Presentation.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildNotificationCard(
          avatarPath: 'images/avatar_female2.png',
          isUnread: false,
          time: '1d ago',
          content: RichText(
            text: TextSpan(
              style: _cardTextStyle,
              children: [
                TextSpan(text: 'Venice ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'assigned you to '),
                TextSpan(text: 'write Objectives part ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'task in '),
                TextSpan(text: 'Capstone Planning.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
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
          content: RichText(
            text: TextSpan(
              style: _cardTextStyle,
              children: [
                TextSpan(text: 'Settle Up ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'Contributions for '),
                TextSpan(text: 'Capstone Planning.\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'Josh requests 350 PHP for Contributions.', style: _mutedTextStyle),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTaskCard(
          avatarPath: 'images/avatar_male.png',
          actionText: 'Vote',
          actionColor: const Color(0xFFF2B73F),
          showAvatarStack: true,
          avatarStackText: '4/8 votes',
          content: RichText(
            text: TextSpan(
              style: _cardTextStyle,
              children: [
                TextSpan(text: '[4/8] ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'Vote on '),
                TextSpan(text: 'Ramen House ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'for '),
                TextSpan(text: 'Dinner sa Japan lang.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTaskCard(
          avatarPath: 'images/avatar_male.png',
          actionText: 'Vote',
          actionColor: const Color(0xFFF2B73F),
          showAvatarStack: true,
          avatarStackText: '3/8 votes',
          content: RichText(
            text: TextSpan(
              style: _cardTextStyle,
              children: [
                TextSpan(text: '[3/8] ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'Vote on '),
                TextSpan(text: 'Ramen House ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'for '),
                TextSpan(text: 'Dinner sa Japan lang.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTaskCard(
          avatarPath: 'images/avatar_female.png',
          actionText: 'Settle Up',
          actionColor: const Color(0xFFF2B73F),
          content: RichText(
            text: TextSpan(
              style: _cardTextStyle,
              children: [
                TextSpan(text: 'Settle Up ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'Contributions for '),
                TextSpan(text: 'Capstone Planning.\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'Josh requests 10,350 PHP for Contributions.', style: _mutedTextStyle),
              ],
            ),
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Theme.of(context).cardColor,
        border: Border.all(
          color: isUnread
              ? const Color(0xFFF2B73F)
              : Theme.of(context).dividerColor,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            backgroundImage: AssetImage(avatarPath),
            // Fallback icon
            onBackgroundImageError: (_, _) {},
            child: const Icon(Icons.person, color: Colors.grey),
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
                      _buildAvatarStack(4), // Display 4 tiny avatars
                      const SizedBox(width: 8),
                      Text(avatarStackText ?? '', style: _mutedTextStyle),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(time, style: _mutedTextStyle),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.06),
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
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            backgroundImage: AssetImage(avatarPath),
            onBackgroundImageError: (_, _) {},
            child: const Icon(Icons.person, color: Colors.grey),
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
                          Text(avatarStackText ?? '', style: _mutedTextStyle),
                        ],
                      )
                    else 
                      const SizedBox.shrink(),
                    
                    // Action Button
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionColor,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Reusable widget to create overlapping avatars
  Widget _buildAvatarStack(int count) {
    return SizedBox(
      width: 24.0 + (16.0 * (count - 1)), // Calculate width based on overlaps
      height: 24,
      child: Stack(
        children: List.generate(count, (index) {
          return Positioned(
            left: index * 16.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
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