import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'theme_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  String? favoriteDriver;
  String? favoriteTeam;
  String? driverImage;
  String? driverSurname;

  Map<String, dynamic>? careerStats;
  Map<String, dynamic>? seasonStats;
  bool loadingStats = false;
  String? statsError;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showCareerStats = true;

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    loadPreferences();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      favoriteDriver = prefs.getString("favorite_driver_name");
      driverImage = prefs.getString("favorite_driver_image");
      favoriteTeam = prefs.getString("favorite_team");
      driverSurname = prefs.getString("favorite_driver_surname");
    });

    if (driverSurname != null && driverSurname!.isNotEmpty) {
      await findDriverIdAndFetchStats(driverSurname!);
    }
  }

  void _flipCard() {
    if (_flipController.status != AnimationStatus.forward) {
      if (_showCareerStats) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
      setState(() {
        _showCareerStats = !_showCareerStats;
      });
    }
  }

  Future<void> findDriverIdAndFetchStats(String surname) async {
    setState(() {
      loadingStats = true;
      statsError = null;
    });

    try {
      final driverId = surname.toLowerCase().replaceAll(' ', '_');

      final testResp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/drivers/$driverId.json'),
      );

      if (testResp.statusCode == 200) {
        final testData = json.decode(testResp.body);
        final drivers = (testData['MRData']['DriverTable']['Drivers'] ?? []) as List<dynamic>;

        if (drivers.isNotEmpty) {
          await fetchDriverCareerStats(driverId);
          await fetchDriverSeasonStats(driverId);
          return;
        }
      }

      final searchResp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/drivers.json?limit=1000'),
      );

      if (searchResp.statusCode == 200) {
        final searchData = json.decode(searchResp.body);
        final allDrivers = (searchData['MRData']['DriverTable']['Drivers'] ?? []) as List<dynamic>;

        final matchedDriver = allDrivers.firstWhere(
              (driver) {
            final familyName = (driver['familyName'] ?? '').toString().toLowerCase();
            final searchLower = surname.toLowerCase();
            return familyName == searchLower ||
                familyName.contains(searchLower) ||
                searchLower.contains(familyName);
          },
          orElse: () => null,
        );

        if (matchedDriver != null) {
          final foundDriverId = matchedDriver['driverId'] as String;
          await fetchDriverCareerStats(foundDriverId);
          await fetchDriverSeasonStats(foundDriverId);
        } else {
          setState(() {
            statsError = "Pilote '$surname' non trouvé";
            loadingStats = false;
          });
        }
      } else {
        setState(() {
          statsError = "Erreur de connexion";
          loadingStats = false;
        });
      }
    } catch (e) {
      setState(() {
        statsError = "Erreur: $e";
        loadingStats = false;
      });
    }
  }

  Future<int> fetchDriverPoles(String driverId) async {
    int totalPoles = 0;
    int offset = 0;
    const int limit = 100;

    while (true) {
      try {
        final resp = await http.get(
          Uri.parse('https://api.jolpi.ca/ergast/f1/drivers/$driverId/qualifying.json?limit=$limit&offset=$offset'),
        );

        if (resp.statusCode != 200) break;

        final data = json.decode(resp.body);
        final races = (data['MRData']['RaceTable']['Races'] ?? []) as List<dynamic>;

        if (races.isEmpty) break;

        for (var race in races) {
          final results = (race['QualifyingResults'] ?? []) as List<dynamic>;
          for (var result in results) {
            if (result['Driver']['driverId'] == driverId && result['position'] == '1') {
              totalPoles++;
            }
          }
        }

        offset += limit;

        if (races.length < limit) break;

      } catch (e) {
        print('Error fetching poles: $e');
        break;
      }
    }

    return totalPoles;
  }

  Future<void> fetchDriverCareerStats(String driverId) async {
    try {
      final winsResp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/drivers/$driverId/results/1.json'),
      );
      final p2Resp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/drivers/$driverId/results/2.json'),
      );
      final p3Resp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/drivers/$driverId/results/3.json'),
      );

      final totalPoles = await fetchDriverPoles(driverId);

      if (winsResp.statusCode == 200 && p2Resp.statusCode == 200 && p3Resp.statusCode == 200) {
        final winsData = json.decode(winsResp.body);
        final p2Data = json.decode(p2Resp.body);
        final p3Data = json.decode(p3Resp.body);

        final totalWins = int.tryParse(winsData['MRData']['total'] ?? '0') ?? 0;
        final p1Count = int.tryParse(winsData['MRData']['total'] ?? '0') ?? 0;
        final p2Count = int.tryParse(p2Data['MRData']['total'] ?? '0') ?? 0;
        final p3Count = int.tryParse(p3Data['MRData']['total'] ?? '0') ?? 0;
        final totalPodiums = p1Count + p2Count + p3Count;

        print('FINAL Career Stats: Wins=$totalWins, Poles=$totalPoles, Podiums=$totalPodiums');

        setState(() {
          careerStats = {
            'wins': totalWins,
            'poles': totalPoles,
            'podiums': totalPodiums,
          };
        });
      }
    } catch (e) {
      print('Error fetching career stats: $e');
    }
  }


  Future<int> fetchDriverSeasonPoles(String driverId, int year) async {
    int seasonPoles = 0;

    try {
      final resp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/$year/drivers/$driverId/qualifying.json'),
      );

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final races = (data['MRData']['RaceTable']['Races'] ?? []) as List<dynamic>;

        for (var race in races) {
          final results = (race['QualifyingResults'] ?? []) as List<dynamic>;
          for (var result in results) {
            if (result['Driver']['driverId'] == driverId && result['position'] == '1') {
              seasonPoles++;
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching season poles: $e');
    }

    return seasonPoles;
  }

  Future<void> fetchDriverSeasonStats(String driverId) async {
    try {
      final currentYear = DateTime.now().year;

      final winsResp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/$currentYear/drivers/$driverId/results/1.json'),
      );

      final podiumsResp = await http.get(
        Uri.parse('https://api.jolpi.ca/ergast/f1/$currentYear/drivers/$driverId/results.json'),
      );

      final seasonPoles = await fetchDriverSeasonPoles(driverId, currentYear);

      if (winsResp.statusCode == 200 && podiumsResp.statusCode == 200) {
        final winsData = json.decode(winsResp.body);
        final podiumsData = json.decode(podiumsResp.body);

        final seasonWins = int.tryParse(winsData['MRData']['total'] ?? '0') ?? 0;

        final races = (podiumsData['MRData']['RaceTable']['Races'] ?? []) as List<dynamic>;
        int seasonPodiums = 0;
        for (var race in races) {
          final results = (race['Results'] ?? []) as List<dynamic>;
          if (results.isNotEmpty) {
            final position = int.tryParse(results[0]['position']?.toString() ?? '0') ?? 0;
            if (position > 0 && position <= 3) {
              seasonPodiums++;
            }
          }
        }

        print('DEBUG Season $currentYear Stats: Wins=$seasonWins, Poles=$seasonPoles, Podiums=$seasonPodiums');

        setState(() {
          seasonStats = {
            'wins': seasonWins,
            'poles': seasonPoles,
            'podiums': seasonPodiums,
            'year': currentYear,
          };
          loadingStats = false;
        });
      } else {
        setState(() {
          loadingStats = false;
        });
      }
    } catch (e) {
      print('Error fetching season stats: $e');
      setState(() {
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
              else if (careerStats != null || seasonStats != null)
                  GestureDetector(
                    onTap: _flipCard,
                    child: AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        final angle = _flipAnimation.value * math.pi;
                        final transform = Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle);

                        return Transform(
                          transform: transform,
                          alignment: Alignment.center,
                          child: angle >= math.pi / 2
                              ? _buildSeasonStatsCard()
                              : _buildCareerStatsCard(),
                        );
                      },
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

  Widget _buildCareerStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeColors.desactive),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "📊 Statistiques de carrière",
                style: TextStyle(
                  color: ThemeColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.flip,
                size: 16,
                color: Colors.white.withOpacity(0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (careerStats != null)
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
    );
  }

  Widget _buildSeasonStatsCard() {
    return Transform(
      transform: Matrix4.rotationY(math.pi),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orangeAccent),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "🏁 Saison ${seasonStats?['year'] ?? DateTime.now().year}",
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.flip,
                  size: 16,
                  color: Colors.white.withOpacity(0.5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (seasonStats != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(
                    icon: "🏆",
                    label: "Victoires",
                    value: seasonStats!['wins'].toString(),
                  ),
                  _buildStatCard(
                    icon: "⚡",
                    label: "Poles",
                    value: seasonStats!['poles'].toString(),
                  ),
                  _buildStatCard(
                    icon: "🥇",
                    label: "Podiums",
                    value: seasonStats!['podiums'].toString(),
                  ),
                ],
              )
            else
              const Text(
                "Aucune donnée pour cette saison",
                style: TextStyle(
                  color: ThemeColors.textSecondary,
                  fontSize: 14,
                ),
              ),
          ],
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
