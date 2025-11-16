import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'home_page.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  String? selectedDriver;
  String? selectedTeam;

  List<String> drivers = [];
  List<String> teams = [];

  bool loading = true;
  String error = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
      error = "";
    });

    try {
      // ——— Pilotes depuis le championnat 2025
      final driversResp = await http.get(
        Uri.parse('https://f1api.dev/api/2025/drivers-championship'),
      );
      if (driversResp.statusCode == 200) {
        final data = json.decode(driversResp.body);
        final list =
        (data["drivers_championship"] ?? []) as List<dynamic>;

        drivers = list
            .map((entry) {
          final driver =
          (entry["driver"] ?? {}) as Map<String, dynamic>;
          final name = (driver["name"] ?? "").toString().trim();
          final surname =
          (driver["surname"] ?? "").toString().trim();
          final full = "$name $surname".trim();
          return full.isEmpty ? null : full;
        })
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
      } else {
        error = "Impossible de charger les pilotes.";
      }

      // ——— Écuries depuis le championnat 2025
      final teamsResp = await http.get(
        Uri.parse(
            'https://f1api.dev/api/2025/constructors-championship'),
      );
      if (teamsResp.statusCode == 200) {
        final data = json.decode(teamsResp.body);
        final list = (data["constructors_championship"] ?? [])
        as List<dynamic>;

        teams = list
            .map((entry) {
          final team =
          (entry["team"] ?? {}) as Map<String, dynamic>;
          final name =
          (team["teamName"] ?? team["name"] ?? "")
              .toString()
              .trim();
          return name.isEmpty ? null : name;
        })
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
      } else {
        if (error.isEmpty) {
          error = "Impossible de charger les écuries.";
        }
      }

      // Charger les préférences déjà enregistrées
      final prefs = await SharedPreferences.getInstance();
      final savedDriver = prefs.getString("favorite_driver");
      final savedTeam = prefs.getString("favorite_team");

      if (savedDriver != null && drivers.contains(savedDriver)) {
        selectedDriver = savedDriver;
      }
      if (savedTeam != null && teams.contains(savedTeam)) {
        selectedTeam = savedTeam;
      }
    } catch (_) {
      error = "Erreur lors du chargement des données.";
    }

    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  Future<void> savePreferences() async {
    if (selectedDriver == null || selectedTeam == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("favorite_driver", selectedDriver!);
    await prefs.setString("favorite_team", selectedTeam!);

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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            error,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Ton pilote préféré",
              style:
              TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedDriver,
              dropdownColor: Colors.black,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.black,
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide.none,
                ),
              ),
              hint: const Text(
                "Choisir...",
                style: TextStyle(color: Colors.white70),
              ),
              items: drivers.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text(
                    d,
                    style:
                    const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) =>
                  setState(() => selectedDriver = value),
            ),
            const SizedBox(height: 40),
            const Text(
              "Ton écurie préférée",
              style:
              TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedTeam,
              dropdownColor: Colors.black,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.black,
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide.none,
                ),
              ),
              hint: const Text(
                "Choisir...",
                style: TextStyle(color: Colors.white70),
              ),
              items: teams.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Text(
                    t,
                    style:
                    const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) =>
                  setState(() => selectedTeam = value),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: savePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 14,
                ),
              ),
              child: const Text(
                "Valider",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
