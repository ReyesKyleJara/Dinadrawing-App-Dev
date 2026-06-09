import 'package:flutter/material.dart';
import '../screens/home/home.dart';
import '../screens/myplans/my_plans.dart';
import '../screens/activity/activity.dart';
import '../screens/settings/settings.dart';
import '../screens/plans/create_plan.dart';
import '../screens/plans/join_plan.dart';
import '../tab/quick_decision.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  late int _currentIndex;
  bool _showMenu = false;
  int _myPlansRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  List<Widget> get _pages => [
        const HomeScreen(),
        MyPlansScreen(
          key: ValueKey('my-plans-$_myPlansRefreshKey'),
        ),
        const ActivityScreen(),
        const SettingsPage(),
      ];

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  Future<void> _openCreatePlan() async {
    _toggleMenu();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreatePlanPage(),
      ),
    );

    if (!mounted) return;

    setState(() {
      _currentIndex = 1;
      _myPlansRefreshKey++;
    });
  }

  Future<void> _openJoinPlan() async {
    _toggleMenu();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const JoinPlanPage(),
      ),
    );

    if (!mounted) return;

    setState(() {
      _currentIndex = 1;
      _myPlansRefreshKey++;
    });
  }

  Future<void> _openQuickDecision() async {
    _toggleMenu();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const QuickDecisionPage(),
      ),
    );
  }

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
      _showMenu = false;

      if (index == 1) {
        _myPlansRefreshKey++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;

    return Scaffold(
      body: Stack(
        children: [
          pages[_currentIndex],

          if (_showMenu)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.transparent,
              ),
            ),

          if (_showMenu)
            Positioned(
              bottom: 95,
              right: 24,
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    _buildMenuItem(
                      Icons.add,
                      "Create Plan",
                      () {
                        _openCreatePlan();
                      },
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 14,
                      endIndent: 14,
                      color: Color(0xFFEEEEEE),
                    ),
                    _buildMenuItem(
                      Icons.link,
                      "Join Plan",
                      () {
                        _openJoinPlan();
                      },
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 14,
                      endIndent: 14,
                      color: Color(0xFFEEEEEE),
                    ),
                    _buildMenuItem(
                      Icons.pie_chart_outline,
                      "Quick Decision",
                      () {
                        _openQuickDecision();
                      },
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
        ],
      ),

      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
          ? SizedBox(
              width: 42,
              height: 42,
              child: FloatingActionButton(
                onPressed: _toggleMenu,
                backgroundColor: const Color(0xFFF2B73F),
                shape: const CircleBorder(),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    _showMenu ? Icons.close : Icons.add,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _changeTab,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFF2B73F),
        unselectedItemColor: Colors.black,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: [
          _buildNavItem(
            'images/navbar-icons/home-icon.png',
            'images/navbar-icons/home-icon_clicked.png',
            0,
            'Home',
          ),
          _buildNavItem(
            'images/navbar-icons/myplans-icon.png',
            'images/navbar-icons/myplans-icon_clicked.png',
            1,
            'My Plans',
          ),
          _buildNavItem(
            'images/navbar-icons/notification-icon.png',
            'images/navbar-icons/notification-icon_clicked.png',
            2,
            'Activity',
          ),
          _buildNavItem(
            'images/navbar-icons/settings-icon.png',
            'images/navbar-icons/settings-icon_clicked.png',
            3,
            'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String text,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFF2B73F),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    String defaultPath,
    String activePath,
    int index,
    String label,
  ) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Image.asset(
          _currentIndex == index ? activePath : defaultPath,
          width: 24,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.error_outline,
              color: Colors.amber,
              size: 24,
            );
          },
        ),
      ),
      label: label,
    );
  }
}