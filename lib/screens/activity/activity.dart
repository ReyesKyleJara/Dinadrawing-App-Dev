import 'package:flutter/material.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // 0 = Notifications, 1 = Pending Tasks
  int _selectedTabIndex = 0; 

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
        const Text(
          'Activity',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        // SAFE AVATAR: Won't crash if the image is missing
        ClipOval(
          child: Image.asset(
            'images/user-avatar.png', // Change this to your actual image path
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? const Color(0xFFF2B73F) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _selectedTabIndex == 0 ? Colors.black : Colors.grey.shade600,
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
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Pending Tasks',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _selectedTabIndex == 1 ? Colors.black : Colors.grey.shade600,
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
        const Text('Today', style: TextStyle(fontSize: 16, color: Colors.black87)),
        const SizedBox(height: 12),
        _buildNotificationCard(
          avatarPath: 'images/avatar_female.png', 
          isUnread: true,
          time: '10 minutes ago',
          content: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.black, height: 1.4),
              children: [
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
            text: const TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.black, height: 1.4),
              children: [
                TextSpan(text: 'Janril ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'voted for the poll you posted in '),
                TextSpan(text: 'Birthday ni Kenny.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        const Text('Yesterday', style: TextStyle(fontSize: 16, color: Colors.black87)),
        const SizedBox(height: 12),
        
        _buildNotificationCard(
          avatarPath: 'images/avatar_female.png',
          isUnread: false,
          time: '1d ago',
          content: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.black, height: 1.4),
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
            text: const TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.black, height: 1.4),
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
            text: const TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.black, height: 1.4),
              children: [
                TextSpan(text: 'Settle Up ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'Contributions for '),
                TextSpan(text: 'Capstone Planning.\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'Josh requests 350 PHP for Contributions.', style: TextStyle(fontSize: 12, color: Colors.black54)),
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
            text: const TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.black, height: 1.4),
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
            text: const TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.black, height: 1.4),
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
            text: const TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.black, height: 1.4),
              children: [
                TextSpan(text: 'Settle Up ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'Contributions for '),
                TextSpan(text: 'Capstone Planning.\n', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'Josh requests 10,350 PHP for Contributions.', style: TextStyle(fontSize: 12, color: Colors.black54)),
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
        color: isUnread ? const Color(0xFFFFF7E6) : Colors.white, // Light yellow if unread
        border: Border.all(color: isUnread ? const Color(0xFFF2B73F) : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade300,
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
                      Text(avatarStackText ?? '', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(time, style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
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
            backgroundColor: Colors.grey.shade300,
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
                          Text(avatarStackText ?? '', style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
                border: Border.all(color: Colors.white, width: 2), // White border for separation
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