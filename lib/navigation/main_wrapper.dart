import 'package:flutter/material.dart';

import '../screens/activity/activity.dart';
import '../screens/home/home.dart';
import '../screens/myplans/my_plans.dart';
import '../screens/plans/create_plan.dart';
import '../screens/plans/join_plan.dart';
import '../screens/settings/settings.dart';
import '../tab/quick_decision.dart';

const Color _brandYellow = Color(0xFFF2B73F);
const Color _brandYellowDark = Color(0xFFD89B22);

class MainWrapper extends StatefulWidget {
  const MainWrapper({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<MainWrapper> createState() {
    return _MainWrapperState();
  }
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

  List<Widget> get _pages {
    return [
      const HomeScreen(),
      MyPlansScreen(
        key: ValueKey(
          'my-plans-$_myPlansRefreshKey',
        ),
      ),
      const ActivityScreen(),
      const SettingsPage(),
    ];
  }

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  void _closeMenu() {
    if (!_showMenu) {
      return;
    }

    setState(() {
      _showMenu = false;
    });
  }

  Future<void> _openCreatePlan() async {
    _closeMenu();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return const CreatePlanPage();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = 1;
      _myPlansRefreshKey++;
    });
  }

  Future<void> _openJoinPlan() async {
    _closeMenu();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return const JoinPlanPage();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = 1;
      _myPlansRefreshKey++;
    });
  }

  Future<void> _openQuickDecision() async {
    _closeMenu();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return const QuickDecisionPage();
        },
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final pages = _pages;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: pages[_currentIndex],
          ),

          if (_showMenu)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeMenu,
                child: Container(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.42 : 0.18,
                  ),
                ),
              ),
            ),

          if (_showMenu)
            Positioned(
              right: 20,
              bottom: 76,
              child: Material(
                color: colors.surface,
                elevation: 14,
                shadowColor: Colors.black.withValues(
                  alpha: isDark ? 0.50 : 0.18,
                ),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: 224,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 7),
                      _buildMenuItem(
                        icon: Icons.add_rounded,
                        text: 'Create Plan',
                        onTap: _openCreatePlan,
                      ),
                      _buildMenuDivider(),
                      _buildMenuItem(
                        icon: Icons.link_rounded,
                        text: 'Join Plan',
                        onTap: _openJoinPlan,
                      ),
                      _buildMenuDivider(),
                      _buildMenuItem(
                        icon: Icons.pie_chart_outline_rounded,
                        text: 'Quick Decision',
                        onTap: _openQuickDecision,
                      ),
                      const SizedBox(height: 7),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      floatingActionButton:
          _currentIndex == 0 || _currentIndex == 1
              ? SizedBox(
                  width: 48,
                  height: 48,
                  child: FloatingActionButton(
                    heroTag: 'main-wrapper-action-button',
                    onPressed: _toggleMenu,
                    backgroundColor: _brandYellow,
                    foregroundColor: Colors.black,
                    elevation: _showMenu ? 8 : 4,
                    shape: const CircleBorder(),
                    child: AnimatedRotation(
                      turns: _showMenu ? 0.125 : 0,
                      duration: const Duration(
                        milliseconds: 180,
                      ),
                      child: Icon(
                        _showMenu
                            ? Icons.close_rounded
                            : Icons.add_rounded,
                        size: 25,
                        color: Colors.black,
                      ),
                    ),
                  ),
                )
              : null,

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(
                alpha: 0.65,
              ),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.25 : 0.06,
              ),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _changeTab,
            type: BottomNavigationBarType.fixed,
            backgroundColor: colors.surface,
            selectedItemColor: _brandYellowDark,
            unselectedItemColor: colors.onSurfaceVariant,
            elevation: 0,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            showSelectedLabels: true,
            showUnselectedLabels: true,
            items: [
              _buildNavItem(
                defaultPath:
                    'images/navbar-icons/home-icon.png',
                activePath:
                    'images/navbar-icons/home-icon_clicked.png',
                index: 0,
                label: 'Home',
              ),
              _buildNavItem(
                defaultPath:
                    'images/navbar-icons/myplans-icon.png',
                activePath:
                    'images/navbar-icons/myplans-icon_clicked.png',
                index: 1,
                label: 'My Plans',
              ),
              _buildNavItem(
                defaultPath:
                    'images/navbar-icons/notification-icon.png',
                activePath:
                    'images/navbar-icons/notification-icon_clicked.png',
                index: 2,
                label: 'Activity',
              ),
              _buildNavItem(
                defaultPath:
                    'images/navbar-icons/settings-icon.png',
                activePath:
                    'images/navbar-icons/settings-icon_clicked.png',
                index: 3,
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuDivider() {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      child: Divider(
        height: 1,
        thickness: 1,
        color: colors.outlineVariant.withValues(
          alpha: 0.70,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: colors.onPrimaryContainer,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required String defaultPath,
    required String activePath,
    required int index,
    required String label,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = _currentIndex == index;

    final iconColor = isSelected
        ? _brandYellowDark
        : colors.onSurfaceVariant;

    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(
          bottom: 4,
        ),
        child: Image.asset(
          isSelected ? activePath : defaultPath,
          width: 24,
          height: 24,
          color: iconColor,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return Icon(
              Icons.error_outline_rounded,
              color: iconColor,
              size: 24,
            );
          },
        ),
      ),
      label: label,
    );
  }
}