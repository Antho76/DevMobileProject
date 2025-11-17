import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'main.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  Map<String, dynamic>? selectedDriver;
  String? selectedTeam;

  List<dynamic> pilotes = [];
  List<dynamic> ecuries = [];
  int selectedYear = 2025;

  // ✅ Map pour stocker les images des pilotes (en arrière-plan)
  Map<String, String?> driverImages = {};

  @override
  void initState() {
    super.initState();
    fetchPilotes();
    fetchEcuries();
  }

  String _driverKey(Map<String, dynamic> driver) {
    final name = (driver['name'] ?? '').toString().trim();
    final surname = (driver['surname'] ?? '').toString().trim();
    return ('$name $surname').toLowerCase();
  }

  Future<String?> fetchDriverImageFromWikipedia(String wikiUrl) async {
    // REST summary thumbnail
    try {
      final uri = Uri.parse(wikiUrl);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final last = segments.last;
        if (last.isNotEmpty) {
          final title = Uri.encodeComponent(last);
          final restUrl = 'https://${uri.host}/api/rest_v1/page/summary/$title';
          final resp = await http.get(
            Uri.parse(restUrl),
            headers: {'User-Agent': 'F1StandingsApp/1.0 (contact@example.com)'},
          );
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body);
            final thumb = data['thumbnail'];
            if (thumb is Map && thumb['source'] is String) {
              return thumb['source'] as String;
            }
          }
        }
      }
    } catch (_) {}

    // Fallback og:image
    try {
      final resp = await http.get(Uri.parse(wikiUrl));
      if (resp.statusCode == 200) {
        final html = resp.body;
        final match = RegExp(r'<meta property="og:image" content="(.*?)"').firstMatch(html);
        if (match != null) return match.group(1);
      }
    } catch (_) {}
    return null;
  }

  Future<void> fetchPilotes() async {
    try {
      final piloteResp = await http.get(
        Uri.parse('https://f1api.dev/api/$selectedYear/drivers-championship'),
      );

      if (piloteResp.statusCode == 200) {
        final piloteData = json.decode(piloteResp.body);
        pilotes = (piloteData['drivers_championship'] ?? []) as List<dynamic>;
      } else {
        pilotes = [];
      }
    } catch (_) {
      pilotes = [];
    }
    setState(() {});

    // ✅ Charger les images en arrière-plan (sans affichage)
    for (final p in pilotes) {
      final driver = (p['driver'] ?? {}) as Map<String, dynamic>;
      final key = _driverKey(driver);
      final url = driver['url'];
      if (url is String && url.isNotEmpty) {
        fetchDriverImageFromWikipedia(url).then((imgUrl) {
          if (!mounted) return;
          if (imgUrl != null) {
            setState(() => driverImages[key] = imgUrl);
          }
        });
      }
    }
  }

  Future<void> fetchEcuries() async {
    try {
      final ecurieResp = await http.get(
        Uri.parse('https://f1api.dev/api/$selectedYear/constructors-championship'),
      );

      if (ecurieResp.statusCode == 200) {
        final ecurieData = json.decode(ecurieResp.body);
        ecuries = (ecurieData['constructors_championship'] ?? []) as List<dynamic>;
      } else {
        ecuries = [];
      }
    } catch (_) {
      ecuries = [];
    }
    setState(() {});
  }

  Future<void> savePreferences() async {
    if (selectedDriver == null || selectedTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un pilote et une écurie')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // ✅ Récupérer l'image depuis le Map driverImages
    final driverKey = _driverKey(selectedDriver!);
    final driverImage = driverImages[driverKey] ?? '';

    final driverSurname = selectedDriver?['surname']?.toString() ?? '';
    // ✅ Sauvegarder l'image récupérée depuis Wikipedia
    await prefs.setString("favorite_driver_image", driverImage);
    await prefs.setString(
      "favorite_driver_name",
      "${selectedDriver?['name'] ?? ''} ${selectedDriver?['surname'] ?? ''}".trim(),
    );
    await prefs.setString("favorite_driver_surname", driverSurname); // ✅ NOUVEAU
    await prefs.setString("favorite_team", selectedTeam!);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainPage()),
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
            DropdownButton<Map<String, dynamic>>(
              dropdownColor: Colors.black,
              value: selectedDriver,
              hint: const Text("Choisir...", style: TextStyle(color: Colors.white70)),
              items: pilotes.map((d) {
                final driver = (d['driver'] ?? {}) as Map<String, dynamic>;
                final fullName = "${driver['name'] ?? ''} ${driver['surname'] ?? ''}".trim();

                return DropdownMenuItem<Map<String, dynamic>>(
                  value: driver,
                  // ✅ Seulement le texte, sans l'image
                  child: Text(fullName, style: const TextStyle(color: Colors.white)),
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
              items: ecuries.map((d) {
                final team = (d['team'] ?? {}) as Map<String, dynamic>;
                final teamName = team['teamName']?.toString() ?? "Unknown";

                return DropdownMenuItem<String>(
                  value: teamName,
                  child: Text(teamName, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedTeam = value),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: (selectedDriver != null && selectedTeam != null)
                  ? savePreferences
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                disabledBackgroundColor: Colors.grey,
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
