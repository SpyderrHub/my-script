import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;

  const BottomNav({Key? key, required this.selectedIndex, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Responsive: scale icons and show labels or only icons in narrow screens
    final width = MediaQuery.of(context).size.width;
    final showLabels = width > 360;

    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          activeIcon: const Icon(Icons.home),
          label: showLabels ? 'Home' : '',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.edit_outlined),
          activeIcon: const Icon(Icons.edit),
          label: showLabels ? 'Edit' : '',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.auto_awesome_outlined),
          activeIcon: const Icon(Icons.auto_awesome),
          label: showLabels ? 'Effects' : '',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.upload_outlined),
          activeIcon: const Icon(Icons.upload),
          label: showLabels ? 'Export' : '',
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person_outline),
          activeIcon: const Icon(Icons.person),
          label: showLabels ? 'Profile' : '',
        ),
      ],
    );
  }
}
