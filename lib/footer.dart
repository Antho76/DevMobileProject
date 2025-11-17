import 'package:flutter/material.dart';
import 'home_page.dart';
import 'ClassementPage.dart';
import 'course_page.dart';
import 'circuit_map_page.dart';
import 'theme_colors.dart';
import 'map.dart';

class Footer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const Footer({super.key, required this.selectedIndex, required this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: ThemeColors.appBar,
      selectedItemColor: ThemeColors.accent,
      unselectedItemColor: ThemeColors.textSecondary,
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.emoji_events),
          label: 'Classement',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.flag),
          label: 'Course',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Circuit',
        ),
      ],
    );
  }
}
