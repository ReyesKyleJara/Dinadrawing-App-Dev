import 'package:flutter/material.dart';
import '../screens/home/home.dart';
import '../screens/myplans/my_plans.dart'; 
import '../screens/activity/activity.dart'; 
import '../screens/settings/settings.dart'; 
import '../screens/plans/create_plan.dart';
import '../screens/plans/join_plan.dart';
import '../screens/quick_decision/quick_decision.dart';

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
                color: Colors.transparent, 
              ),
            ),

          // --- Custom Popup Menu (repositioned and shrunk) ---
          if (_showMenu)
            Positioned(
              // Inadjust natin ito pataas (mula 85) para hiwalay na sa FAB, di na sila overlap.
              bottom: 95, 
              right: 24, 
              child: Container(
                width: 220, 
                decoration: BoxDecoration(
                  color: Colors.white,
                  // Slightly smaller corner radius for a tighter look
                  borderRadius: BorderRadius.circular(16), 
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12, 
                      blurRadius: 15, 
                      offset: Offset(0, 8)
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6), // reduced from 8
                    _buildMenuItem(Icons.add, "Create Plan", () {
                      _toggleMenu();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePlanPage()));
                    }),
                    const Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: Color(0xFFEEEEEE)),
                    _buildMenuItem(Icons.link, "Join Plan", () {
                      _toggleMenu();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinPlanPage()));
                    }),
                    const Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: Color(0xFFEEEEEE)),
                    _buildMenuItem(Icons.pie_chart_outline, "Quick Decision", () { 
                      _toggleMenu();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickDecisionPage()));
                    }),
                    const SizedBox(height: 6), // reduced from 8
                  ],
                ),
              ),
            ),
        ],
      ),
      
      // --- Floating Action Button (Now Mini size) ---
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1) 
        ? Container(
            // Liitan pa natin lalo ang FAB container
            width: 42, // Shrunk from 50
            height: 42, // Shrunk from 50
            child: FloatingActionButton(
              onPressed: _toggleMenu,
              backgroundColor: const Color(0xFFF2B73F),
              shape: const CircleBorder(),
              elevation: 3, // slightly less elevation for a cleaner look
              // Liitan natin ang padding sa icon para proportioned sya sa maliit na button
              child: Padding(
                padding: const EdgeInsets.all(4.0), // reduced padding
                child: Icon(_showMenu ? Icons.close : Icons.add, color: Colors.white, size: 22), // icon shrunk to 22
              ),
            ),
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
        selectedFontSize: 11,   
        unselectedFontSize: 11, 
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
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

  // --- Updated Menu Item UI (Shrunk) ---
  Widget _buildMenuItem(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        // Reduced vertical and horizontal padding for a tighter fit
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Row(
          children: [
            Container(
              // Liitan natin ang yellow circle container
              width: 28, // Shrunk from 32
              height: 28, // Shrunk from 32
              decoration: const BoxDecoration(
                color: Color(0xFFF2B73F), 
                shape: BoxShape.circle,
              ),
              // Liitan din natin ang icon sa loob nito
              child: Icon(icon, color: Colors.white, size: 16), // shrunk to 16
            ),
            const SizedBox(width: 12), // reduced from 16
            Text(
              text, 
              style: const TextStyle(
                fontWeight: FontWeight.w500, 
                // Liitan natin ang text size mula 14 to 13
                fontSize: 13, 
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
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4.0), 
        child: Image.asset(
          _currentIndex == index ? activePath : defaultPath,
          width: 24, 
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline, color: Colors.amber, size: 24),
        ),
      ),
      label: label,
    );
  }
}