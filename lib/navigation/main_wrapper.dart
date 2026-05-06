import 'package:flutter/material.dart';
import '../screens/home/home.dart';
import '../screens/myplans/my_plans.dart'; // 1. Added this import (Adjust the path if you saved it differently)

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(), 
    MyPlansScreen(), // 2. Replaced the placeholder with your new My Plans Screen
    PageContainer(child: Text('Notifications')),
    PageContainer(child: Text('Settings')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
  currentIndex: _currentIndex,
  onTap: (index) {
    setState(() {
      _currentIndex = index;
    });
  },
  type: BottomNavigationBarType.fixed,
  backgroundColor: Colors.white,
  
  // Styling para sa Labels
  selectedItemColor: const Color(0xFFF2B73F), // Kulay nung active icon mo
  unselectedItemColor: Colors.black,           // Kulay nung inactive icons
  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
  unselectedLabelStyle: const TextStyle(fontSize: 12),
  
  // I-set natin sa true pareho para makita ang labels
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

class PageContainer extends StatelessWidget {
  final Widget child;
  const PageContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SafeArea(child: Center(child: child)),
    );
  }
}