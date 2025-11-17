import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? favoriteDriver;
  String? favoriteTeam;
  String? driverImage;
  String? driverSurname;

  Map<String, dynamic>? careerStats;
  bool loadingStats = false;
  String? statsError;

  @override
  void initState() {
    super.initState();
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      favoriteDriver = prefs.getString("favorite_driver_name");
      driverImage = prefs.getString("favorite_driver_image");
      favoriteTeam = prefs.getString("favorite_team");
      driverSurname = prefs.getString("favorite_driver_surname");
    });

    // ✅ Debug: Afficher le surname récupéré
    print('DEBUG: Driver surname = $driverSurname');

    if (driverSurname != null && driverSurname!.isNotEmpty) {
      await findDriverIdAndFetchStats(driverSurname!);
    }
  }

  // ✅ VERSION CORRIGÉE: Recherche améliorée du pilote
  Future<void> findDriverIdAndFetchStats(String surname) async {
    setState(() {
      loadingStats = true;
      statsError = null;
    });

    try {
      // ✅ Rechercher directement par driverId (format: nom de famille en minuscule)
      // Ex: "Verstappen" -> "verstappen", "Hamilton" -> "hamilton"
      final driverId = surname.toLowerCase().replaceAll(' ', '_');

      print('DEBUG: Trying driverId = $driverId');

      // Essayer d'abord avec le driverId généré
      final testResp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/drivers/$driverId.json'),
      );

      if (testResp.statusCode == 200) {
        final testData = json.decode(testResp.body);
        final drivers = (testData['MRData']['DriverTable']['Drivers'] ?? []) as List<dynamic>;

        if (drivers.isNotEmpty) {
          print('DEBUG: Driver found with direct ID');
          await fetchDriverCareerStats(driverId);
          return;
        }
      }

      // ✅ Si ça ne marche pas, rechercher dans la liste complète
      print('DEBUG: Direct ID failed, searching in full list');
      final searchResp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/drivers.json?limit=1000'),
      );

      if (searchResp.statusCode == 200) {
        final searchData = json.decode(searchResp.body);
        final allDrivers = (searchData['MRData']['DriverTable']['Drivers'] ?? []) as List<dynamic>;

        print('DEBUG: Found ${allDrivers.length} drivers in database');

        // ✅ Chercher avec familyName (pas surname!)
        final matchedDriver = allDrivers.firstWhere(
              (driver) {
            final familyName = (driver['familyName'] ?? '').toString().toLowerCase();
            final givenName = (driver['givenName'] ?? '').toString().toLowerCase();
            final searchLower = surname.toLowerCase();

            // Recherche flexible: familyName exact ou contient
            return familyName == searchLower ||
                familyName.contains(searchLower) ||
                searchLower.contains(familyName);
          },
          orElse: () => null,
        );

        if (matchedDriver != null) {
          final foundDriverId = matchedDriver['driverId'] as String;
          print('DEBUG: Matched driver - driverId: $foundDriverId, familyName: ${matchedDriver['familyName']}');
          await fetchDriverCareerStats(foundDriverId);
        } else {
          print('DEBUG: No match found for surname: $surname');
          setState(() {
            statsError = "Pilote '$surname' non trouvé";
            loadingStats = false;
          });
        }
      } else {
        setState(() {
          statsError = "Erreur de connexion (${searchResp.statusCode})";
          loadingStats = false;
        });
      }
    } catch (e) {
      print('DEBUG: Exception = $e');
      setState(() {
        statsError = "Erreur: $e";
        loadingStats = false;
      });
    }
  }

  Future<void> fetchDriverCareerStats(String driverId) async {
    try {
      print('DEBUG: Fetching stats for driverId = $driverId');

      final winsResp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/drivers/$driverId/results/1.json'),
      );

      final polesResp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/drivers/$driverId/qualifying/1.json'),
      );

      final podiumsResp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/drivers/$driverId/results.json?limit=1000'),
      );

      if (winsResp.statusCode == 200 && polesResp.statusCode == 200 && podiumsResp.statusCode == 200) {
        final winsData = json.decode(winsResp.body);
        final polesData = json.decode(polesResp.body);
        final podiumsData = json.decode(podiumsResp.body);

        final totalWins = int.tryParse(winsData['MRData']['total'] ?? '0') ?? 0;
        final totalPoles = int.tryParse(polesData['MRData']['total'] ?? '0') ?? 0;

        final races = (podiumsData['MRData']['RaceTable']['Races'] ?? []) as List<dynamic>;
        int totalPodiums = 0;
        for (var race in races) {
          final results = (race['Results'] ?? []) as List<dynamic>;
          if (results.isNotEmpty) {
            final position = int.tryParse(results[0]['position']?.toString() ?? '0') ?? 0;
            if (position > 0 && position <= 3) {
              totalPodiums++;
            }
          }
        }

        print('DEBUG: Stats - Wins: $totalWins, Poles: $totalPoles, Podiums: $totalPodiums');

        setState(() {
          careerStats = {
            'wins': totalWins,
            'poles': totalPoles,
            'podiums': totalPodiums,
          };
          loadingStats = false;
        });
      } else {
        setState(() {
          statsError = "Erreur de chargement (${winsResp.statusCode})";
          loadingStats = false;
        });
      }
    } catch (e) {
      print('DEBUG: Stats exception = $e');
      setState(() {
        statsError = "Erreur réseau";
        loadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      appBar: AppBar(
        title: const Text("🏠 Accueil"),
        backgroundColor: ThemeColors.appBar,
        centerTitle: true,
      ),
      body: Center(
        child: favoriteDriver == null || favoriteTeam == null
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Bienvenue dans ton app F1 🏎️",
                style: TextStyle(
                  color: ThemeColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              Text(
                "👤 Pilote préféré :",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),

              if (driverImage != null && driverImage!.isNotEmpty)
                ClipOval(
                  child: Image.network(
                    driverImage!,
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 120,
                        width: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ThemeColors.card,
                          shape: BoxShape.circle,
                        ),
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: ThemeColors.card,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 60,
                          color: ThemeColors.textSecondary,
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: ThemeColors.card,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: ThemeColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 10),

              Text(
                favoriteDriver!,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),
              if (loadingStats)
                const CircularProgressIndicator()
              else if (statsError != null)
                Text(
                  statsError!,
                  style: const TextStyle(
                    color: ThemeColors.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                )
              else if (careerStats != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ThemeColors.desactive),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "📊 Statistiques de carrière",
                          style: TextStyle(
                            color: ThemeColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatCard(
                              icon: "🏆",
                              label: "Victoires",
                              value: careerStats!['wins'].toString(),
                            ),
                            _buildStatCard(
                              icon: "⚡",
                              label: "Poles",
                              value: careerStats!['poles'].toString(),
                            ),
                            _buildStatCard(
                              icon: "🥇",
                              label: "Podiums",
                              value: careerStats!['podiums'].toString(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

              const SizedBox(height: 24),

              Text(
                "🏁 Écurie préférée :",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                favoriteTeam!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.orangeAccent,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: ThemeColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
