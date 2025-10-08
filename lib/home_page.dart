import 'package:flutter/material.dart';
import 'theme_colors.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      appBar: AppBar(
        title: const Text("🏠 Accueil"),
        backgroundColor: ThemeColors.appBar,
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "Bienvenue dans ton app F1 🏎️",
          style: TextStyle(
            color: ThemeColors.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
