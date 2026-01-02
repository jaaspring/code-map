import 'package:flutter/material.dart';
import 'package:code_map/screens/user/profile_screen.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  static const Color geekGreen = Color(0xFF4BC945);

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        // Home - call parent callback
        widget.onTap(index);
        break;
      case 1:
        // Categories/Grid
        widget.onTap(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Categories feature coming soon!'),
            backgroundColor: geekGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case 2:
        // Time/History
        widget.onTap(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('History feature coming soon!'),
            backgroundColor: geekGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case 3:
        // Profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(),
          ),
        );
        // Don't update the selected index for profile navigation
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: geekGreen.withOpacity(0.2), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: geekGreen.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomNavItem(
            context,
            Icons.home,
            'Home',
            0,
          ),
          _buildBottomNavItem(
            context,
            Icons.grid_3x3_outlined,
            'Categories',
            1,
          ),
          _buildBottomNavItem(
            context,
            Icons.access_time_outlined,
            'History',
            2,
          ),
          _buildBottomNavItem(
            context,
            Icons.person_outline,
            'Profile',
            3,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    bool isSelected = widget.currentIndex == index;

    return GestureDetector(
      onTap: () => _handleNavigation(context, index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? geekGreen : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: isSelected ? geekGreen : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: geekGreen,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: geekGreen.withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Alternative simpler version without labels
class SimpleBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const SimpleBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  static const Color geekGreen = Color(0xFF4BC945);

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        // Home
        onTap(index);
        break;
      case 1:
        // Categories
        onTap(index);
        break;
      case 2:
        // History
        onTap(index);
        break;
      case 3:
        // Profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: geekGreen.withOpacity(0.2), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomNavItem(context, Icons.home, 0),
          _buildBottomNavItem(context, Icons.grid_3x3_outlined, 1),
          _buildBottomNavItem(context, Icons.access_time_outlined, 2),
          _buildBottomNavItem(context, Icons.person_outline, 3),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(BuildContext context, IconData icon, int index) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => _handleNavigation(context, index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? geekGreen : Colors.grey.shade600,
              size: 24,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: geekGreen,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: geekGreen.withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}