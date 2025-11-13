import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accident_provider.dart';
import 'map_screen.dart';
import 'camera_screen.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = [
    MapScreen(),
    const CameraScreen(),
    const HistoryScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load accidents when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AccidentProvider>(context, listen: false).loadAccidents();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Газрын зураг',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Мэдээлэх',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Түүх',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Мэдэгдэл',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профайл',
          ),
        ],
      ),
    );
  }
}
