import 'package:flutter/material.dart';
import '../screens/home/home.dart';
import '../screens/myplans/my_plans.dart'; 
import '../screens/activity/activity.dart'; 
import '../screens/settings/settings.dart'; 
import '../screens/plans/create_plan.dart';
import '../screens/plans/join_plan.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;
  bool _showMenu = false; 

  final List<Widget> _pages = [
    const HomeScreen(), 
    const MyPlansScreen(), 
    const ActivityScreen(), 
    const SettingsPage(), 
  ];

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          
          // Transparent overlay to close menu when tapping outside
          if (_showMenu)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.transparent, // Changed to transparent to match the clean look
              ),
            ),

          // The New Custom Popup Menu
          if (_showMenu)
            Positioned(
              bottom: 90, 
              right: 24, 
              child: Container(
                width: 220, // Set a fixed width so all items align nicely
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20), // Slightly rounder corners
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 8))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8), // Top padding
                    _buildMenuItem(Icons.add, "Create Plan", () {
                      _toggleMenu();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePlanPage()));
                    }),
                    const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),
                    _buildMenuItem(Icons.link, "Join Plan", () {
                      _toggleMenu();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinPlanPage()));
                    }),
                    const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),
                    _buildMenuItem(Icons.pie_chart_outline, "Quick Decision", () { // pie_chart_outline looks like a wheel!
                      _toggleMenu();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quick Decision coming soon")));
                    }),
                    const SizedBox(height: 8), // Bottom padding
                  ],
                ),
              ),
            ),
        ],
      ),
      
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1) 
        ? FloatingActionButton(
            onPressed: _toggleMenu,
            backgroundColor: const Color(0xFFF2B73F),
            shape: const CircleBorder(),
            elevation: 4,
            child: Icon(_showMenu ? Icons.close : Icons.add, color: Colors.white, size: 30),
          )
        : null, 
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _showMenu = false; 
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFF2B73F), 
        unselectedItemColor: Colors.black,           
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: [
          _buildNavItem('images/navbar-icons/home-icon.png', 'images/navbar-icons/home-icon_clicked.png', 0, 'Home'),
          _buildNavItem('images/navbar-icons/myplans-icon.png', 'images/navbar-icons/myplans-icon_clicked.png', 1, 'My Plans'),
          _buildNavItem('images/navbar-icons/notification-icon.png', 'images/navbar-icons/notification-icon_clicked.png', 2, 'Activity'),
          _buildNavItem('images/navbar-icons/settings-icon.png', 'images/navbar-icons/settings-icon_clicked.png', 3, 'Settings'),
        ],
      ),
    );
  }

  // --- The Updated UI Helper for the Menu Item ---
  Widget _buildMenuItem(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFF2B73F), // The yellow background
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20), // The white icon
            ),
            const SizedBox(width: 16),
            Text(
              text, 
              style: const TextStyle(
                fontWeight: FontWeight.w500, 
                fontSize: 16, // Slightly larger text to match design
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(String defaultPath, String activePath, int index, String label) {
    return BottomNavigationBarItem(
      icon: Image.asset(
        _currentIndex == index ? activePath : defaultPath,
        width: 28,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline, color: Colors.amber),
      ),
      label: label,
    );
  }
}