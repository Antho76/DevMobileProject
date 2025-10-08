import 'package:flutter/material.dart';
import 'theme_colors.dart';

class CircuitPage extends StatelessWidget {
  const CircuitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      appBar: AppBar(
        title: const Text("🗺️ Circuits"),
        backgroundColor: ThemeColors.appBar,
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "Liste des circuits du championnat",
          style: TextStyle(
            color: ThemeColors.textPrimary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
