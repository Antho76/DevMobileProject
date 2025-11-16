import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<PreferencesPage> {
  String? selectedDriver;
  String? selectedTeam;

  final drivers = [
    "Max Verstappen",
    "Lewis Hamilton",
    "Charles Leclerc",
    "Lando Norris",
    "Fernando Alonso",
  ];

  final teams = [
    "Red Bull",
    "Ferrari",
    "Mercedes",
    "McLaren",
    "Aston Martin",
  ];

  Future<void> savePreferences() async {
    if (selectedDriver == null || selectedTeam == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("favorite_driver", selectedDriver!);
    await prefs.setString("favorite_team", selectedTeam!);

    // Passe directement à l'app
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        title: const Text("Choisis ton pilote & ton écurie"),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Ton pilote préféré",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            DropdownButton<String>(
              dropdownColor: Colors.black,
              value: selectedDriver,
              hint: const Text("Choisir...", style: TextStyle(color: Colors.white70)),
              items: drivers.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text(d),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedDriver = value),
            ),
            const SizedBox(height: 40),

            const Text(
              "Ton écurie préférée",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            DropdownButton<String>(
              dropdownColor: Colors.black,
              value: selectedTeam,
              hint: const Text("Choisir...", style: TextStyle(color: Colors.white70)),
              items: teams.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Text(t),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedTeam = value),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: savePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
              child: const Text(
                "Valider",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
