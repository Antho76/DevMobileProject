import 'package:flutter/material.dart';
import 'theme_colors.dart';

class CoursePage extends StatelessWidget {
  const CoursePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      appBar: AppBar(
        title: const Text("🏁 Courses"),
        backgroundColor: ThemeColors.appBar,
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "Liste des courses à venir et passées",
          style: TextStyle(
            color: ThemeColors.textPrimary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
