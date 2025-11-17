import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'LikeHeart.dart';
import 'PreferencesPage.dart';
import 'theme_colors.dart';

class ClassementPage extends StatefulWidget {
  const ClassementPage({super.key});

  @override
  State<ClassementPage> createState() => _ClassementPageState();
}

class _ClassementPageState extends State<ClassementPage> {
  bool loading = true;
  String error = "";
  bool showPilotes = true;
  int selectedYear = DateTime
      .now()
      .year;

  List<dynamic> pilotes = [];
  List<dynamic> constructors = [];

  bool pilotesAvailable = true;
  bool constructorsAvailable = true;

  // Pilote -> URL photo
  final Map<String, String?> driverImages = {};

  // Team -> URL logo
  final Map<String, String?> teamLogos = {};
  final Set<String> _inFlightTeams = {};

  // Favoris (single selection) : clés internes + valeurs préférences
  String? _favoriteDriverKey;
  String? _favoriteTeamKey;
  String? _favoriteDriverName; // pour synchro avec prefs
  String? _favoriteTeamName;

  @override
  void initState() {
    super.initState();
    _loadPreferencesAndData();
  }

  Future<void> _loadPreferencesAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteDriverName = prefs.getString("favorite_driver");
    _favoriteTeamName = prefs.getString("favorite_team");
    await fetchData();
  }

  String _driverKey(Map<String, dynamic> driver) {
    final name = (driver['name'] ?? '').toString().trim();
    final surname = (driver['surname'] ?? '').toString().trim();
    return ('$name $surname').toLowerCase();
  }

  String _driverDisplayName(Map<String, dynamic> driver) {
    final name = (driver['name'] ?? '').toString().trim();
    final surname = (driver['surname'] ?? '').toString().trim();
    return "$name $surname".trim();
  }

  String _teamKey(String? name) => (name ?? '').trim().toLowerCase();

  Future<void> _openDriverUrl(String? urlStr) async {
    if (urlStr == null || urlStr
        .trim()
        .isEmpty) return;
    Uri? uri = Uri.tryParse(urlStr.trim());
    if (uri == null || uri.scheme.isEmpty) {
      uri = Uri.tryParse('https://${urlStr.trim()}');
    }
    if (uri == null) return;

    final okExternal =
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!okExternal) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> fetchData() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = "";
        pilotes = [];
        constructors = [];
        pilotesAvailable = true;
        constructorsAvailable = true;
        driverImages.clear();
        teamLogos.clear();
        _inFlightTeams.clear();
      });
    }

    // Pilotes
    try {
      final piloteResp = await http.get(
        Uri.parse(
          'https://f1api.dev/api/$selectedYear/drivers-championship',
        ),
      );
      if (piloteResp.statusCode == 200) {
        final piloteData = json.decode(piloteResp.body);
        pilotes =
        (piloteData['drivers_championship'] ?? []) as List<dynamic>;
      } else {
        pilotes = [];
      }
    } catch (_) {
      pilotes = [];
    }

    // Constructeurs
    try {
      final constructorResp = await http.get(
        Uri.parse(
          'https://f1api.dev/api/$selectedYear/constructors-championship',
        ),
      );
      if (constructorResp.statusCode == 200) {
        final constructorData = json.decode(constructorResp.body);
        constructors =
        (constructorData['constructors_championship'] ?? [])
        as List<dynamic>;
      } else {
        constructors = [];
      }
    } catch (_) {
      constructors = [];
    }

    // Recalage des clés de favoris à partir des noms prefs
    _favoriteDriverKey = null;
    _favoriteTeamKey = null;

    if (_favoriteDriverName != null) {
      for (final p in pilotes) {
        final driver = (p['driver'] ?? {}) as Map<String, dynamic>;
        final displayName = _driverDisplayName(driver);
        if (displayName == _favoriteDriverName) {
          _favoriteDriverKey = _driverKey(driver);
          break;
        }
      }
    }

    if (_favoriteTeamName != null) {
      for (final t in constructors) {
        final team = (t['team'] ?? {}) as Map<String, dynamic>;
        final teamName = team['teamName']?.toString().trim();
        if (teamName == _favoriteTeamName) {
          _favoriteTeamKey = _teamKey(teamName);
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      pilotesAvailable = pilotes.isNotEmpty;
      constructorsAvailable = constructors.isNotEmpty;

      if (showPilotes && !pilotesAvailable) {
        showPilotes = constructorsAvailable;
      }
      if (!showPilotes && !constructorsAvailable) {
        showPilotes = pilotesAvailable;
      }

      if (!pilotesAvailable && !constructorsAvailable) {
        error = "Aucune information disponible pour cette année.";
      }

      loading = false;
    });

    // Charger images pilotes + logos équipes en arrière-plan
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

      final team = (p['team'] ?? {}) as Map<String, dynamic>;
      final teamName = team['teamName']?.toString();
      _ensureTeamLogo(teamName);
    }

    for (final t in constructors) {
      final team = (t['team'] ?? {}) as Map<String, dynamic>;
      final teamName = team['teamName']?.toString();
      _ensureTeamLogo(teamName);
    }
  }

  // —————————————————— Images pilotes (Wikipédia)
  Future<String?> fetchDriverImageFromWikipedia(String wikiUrl) async {
    try {
      final uri = Uri.parse(wikiUrl);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final last = segments.last;
        if (last.isNotEmpty) {
          final title = Uri.encodeComponent(last);
          final restUrl =
              'https://${uri.host}/api/rest_v1/page/summary/$title';
          final resp = await http.get(
            Uri.parse(restUrl),
            headers: {
              'User-Agent': 'F1StandingsApp/1.0 (contact@example.com)'
            },
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

    try {
      final resp = await http.get(Uri.parse(wikiUrl));
      if (resp.statusCode == 200) {
        final html = resp.body;
        final match = RegExp(
          r'<meta property="og:image" content="(.*?)"',
        ).firstMatch(html);
        if (match != null) return match.group(1);
      }
    } catch (_) {}
    return null;
  }

  // —————————————————— Logos d’écuries
  Future<void> _ensureTeamLogo(String? teamName) async {
    final key = _teamKey(teamName);
    if (key.isEmpty) return;
    if (teamLogos.containsKey(key) || _inFlightTeams.contains(key)) return;

    _inFlightTeams.add(key);
    try {
      final wikiTitle = _guessWikipediaTitleForTeam(teamName);
      final wikiUrl = 'https://en.wikipedia.org/wiki/$wikiTitle';

      final logo = await _fetchTeamLogoFromWikipedia(wikiUrl);
      if (!mounted) return;
      setState(() => teamLogos[key] = logo);
    } finally {
      _inFlightTeams.remove(key);
    }
  }

  String _guessWikipediaTitleForTeam(String? teamName) {
    final raw = (teamName ?? '').trim();
    final map = <String, String>{
      'scuderia ferrari': 'Scuderia_Ferrari',
      'mercedes': 'Mercedes_AMG_Petronas_F1_Team',
      'red bull racing': 'Red_Bull_Racing',
      'oracle red bull racing': 'Red_Bull_Racing',
      'mclaren': 'McLaren',
      'aston martin': 'Aston_Martin_in_Formula_One',
      'alpine': 'Alpine_F1_Team',
      'rb': 'RB_Formula_One_Team',
      'stake f1 team kick sauber': 'Stake_F1_Team_Kick_Sauber',
      'sauber': 'Sauber_Motorsport',
      'haas': 'Haas_F1_Team',
      'williams': 'Williams_Grand_Prix_Engineering',
      'alphatauri': 'Scuderia_AlphaTauri',
      'alfa romeo': 'Alfa_Romeo_in_Formula_One',
      'renault': 'Renault_in_Formula_One',
      'toro rosso': 'Scuderia_Toro_Rosso',
    };
    final key = raw.toLowerCase();
    if (map.containsKey(key)) return map[key]!;
    return raw.replaceAll(' ', '_');
  }

  Future<String?> _fetchTeamLogoFromWikipedia(String wikiUrl) async {
    try {
      final uri = Uri.parse(wikiUrl);
      final host = uri.host;
      final title = Uri.encodeComponent(uri.pathSegments.last);
      final restUrl =
          'https://$host/api/rest_v1/page/summary/$title';
      final resp = await http.get(
        Uri.parse(restUrl),
        headers: {
          'User-Agent': 'F1StandingsApp/1.0 (contact@example.com)'
        },
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final thumb = data['thumbnail'];
        if (thumb is Map && thumb['source'] is String) {
          return thumb['source'] as String;
        }
        final orig = data['originalimage'];
        if (orig is Map && orig['source'] is String) {
          return orig['source'] as String;
        }
      }
    } catch (_) {}

    try {
      final resp = await http.get(Uri.parse(wikiUrl));
      if (resp.statusCode == 200) {
        final html = resp.body;
        final match = RegExp(
          r'<meta property="og:image" content="(.*?)"',
        ).firstMatch(html);
        if (match != null) return match.group(1);
      }
    } catch (_) {}

    return null;
  }

  void showDriverDetailsPopin(BuildContext context,
      Map<String, dynamic> driver, {
        String? initialImageUrl,
      }) {
    final name = _driverDisplayName(driver);
    final key = _driverKey(driver);
    String? imgUrl = initialImageUrl ?? driverImages[key];
    var requested = false;

    showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setStateDialog) {
              if (!requested &&
                  imgUrl == null &&
                  driver['url'] is String &&
                  (driver['url'] as String).isNotEmpty) {
                requested = true;
                Future.microtask(() async {
                  final fetched = await fetchDriverImageFromWikipedia(
                    driver['url'] as String,
                  );
                  if (fetched != null) {
                    if (!mounted) return;
                    setStateDialog(() => imgUrl = fetched);
                    setState(() => driverImages[key] = fetched);
                  } else {
                    if (!mounted) return;
                    setState(() => driverImages[key] = null);
                  }
                });
              }

              return AlertDialog(
                backgroundColor: ThemeColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  name,
                  style: const TextStyle(color: ThemeColors.textPrimary),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imgUrl != null && imgUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imgUrl!,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderBox(),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return _placeholderBox();
                          },
                        ),
                      )
                    else
                      _placeholderBox(),
                    const SizedBox(height: 8),
                    Text(
                      "Date de naissance : ${driver['birthday'] ?? 'N/A'}",
                      style: const TextStyle(color: ThemeColors.textSecondary),
                    ),
                    Text(
                      "Nationalité : ${driver['nationality'] ?? 'N/A'}",
                      style: const TextStyle(color: ThemeColors.textSecondary),
                    ),
                    Text(
                      "Numéro : ${driver['number'] ?? 'N/A'}",
                      style: const TextStyle(color: ThemeColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => _openDriverUrl(driver['url'] as String?),
                      child: Text(
                        "Plus d'infos",
                        style: TextStyle(
                          color: ThemeColors.selected,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Fermer",
                      style: TextStyle(color: ThemeColors.textPrimary),
                    ),
                  )
                ],
              );
            },
          ),
    );
  }

  Widget _placeholderBox() =>
      Container(
        height: 120,
        width: 120,
        alignment: Alignment.center,
        color: ThemeColors.background,
        child: const Icon(
          Icons.person,
          size: 48,
          color: ThemeColors.textSecondary,
        ),
      );

  Future<void> handleDriverSelection(Map<String, dynamic> driver) async {
    final surname = (driver['surname'] ?? '').toString().trim();
    final name = (driver['name'] ?? '').toString().trim();
    if (surname.isEmpty || name.isEmpty) return;

    try {
      final resp = await http.get(
        Uri.parse(
          "https://f1api.dev/api/drivers/search?q=$surname",
        ),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final drivers = (data['drivers'] ?? []) as List<dynamic>;

        if (drivers.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucun pilote trouvé.")),
          );
        } else {
          final matchedDriver = drivers.firstWhere(
                (d) => (d['name'] == name && d['surname'] == surname),
            orElse: () => drivers[0],
          ) as Map<String, dynamic>;
          if (!mounted) return;
          showDriverDetailsPopin(context, matchedDriver);
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible de récupérer les détails du pilote."),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur lors de la récupération du pilote."),
        ),
      );
    }
  }

  Future<void> _openSearchPopin() async {
    final chosen = await showDialog<dynamic>(
      context: context,
      builder: (context) =>
          SearchPopin(
            minYear: 1950,
            initialYear: selectedYear,
            onDriverSelected: handleDriverSelection,
          ),
    );

    if (chosen != null && chosen is int) {
      if (!mounted) return;
      setState(() => selectedYear = chosen);
      await fetchData();
    }
  }

  Widget _buildDriverAvatar({
    required String driverKey,
    required int position,
    double size = 40,
  }) {
    final url = driverImages[driverKey];

    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        child: Text('$position'),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return CircleAvatar(
              radius: size / 2,
              child: Text('$position'),
            );
          },
          errorBuilder: (_, __, ___) =>
              CircleAvatar(
                radius: size / 2,
                child: Text('$position'),
              ),
        ),
      ),
    );
  }

  // tronque le nom d’écurie en fonction de la largeur écran
  String _truncateTeamNameForDevice(BuildContext context, String? name) {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return '';
    final width = MediaQuery
        .of(context)
        .size
        .width;
    int maxChars;
    if (width < 340) {
      maxChars = 12;
    } else if (width < 380) {
      maxChars = 12;
    } else if (width < 500) {
      maxChars = 12;
    } else {
      maxChars = 30;
    }
    if (raw.length <= maxChars) return raw;
    return '${raw.substring(0, maxChars - 1)}…';
  }

  Widget _buildTeamChip(String? teamName) {
    final truncated = _truncateTeamNameForDevice(context, teamName);
    final key = _teamKey(teamName);
    final logo = teamLogos[key];
    final initials = (teamName ?? '')
        .split(RegExp(r'[\s-]+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first.toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ThemeColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThemeColors.desactive),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logo != null && logo.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                logo,
                height: 18,
                width: 18,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _teamInitials(initials),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _teamInitials(initials);
                },
              ),
            )
          else
            _teamInitials(initials),
          const SizedBox(width: 6),
          Text(
            truncated,
            style: const TextStyle(
              color: ThemeColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
          ),
        ],
      ),
    );
  }

  Widget _teamInitials(String initials) =>
      Container(
        height: 18,
        width: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ThemeColors.desactive,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Future<void> _updateFavoriteDriver(String? key, String? displayName) async {
    _favoriteDriverKey = key;
    _favoriteDriverName = displayName;

    final prefs = await SharedPreferences.getInstance();
    if (displayName == null) {
      await prefs.remove("favorite_driver");
    } else {
      await prefs.setString("favorite_driver", displayName);
    }
  }

  Future<void> _updateFavoriteTeam(String? key, String? name) async {
    _favoriteTeamKey = key;
    _favoriteTeamName = name;

    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove("favorite_team");
    } else {
      await prefs.setString("favorite_team", name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataList = showPilotes ? pilotes : constructors;
    final isSmallScreen = MediaQuery
        .of(context)
        .size
        .width < 360;

    return Scaffold(
      backgroundColor: ThemeColors.background,
      appBar: AppBar(
        title: Text("🏆 Classement F1 $selectedYear"),
        backgroundColor: ThemeColors.appBar,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Rechercher",
            onPressed: _openSearchPopin,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Préférences",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PreferencesPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(
        child: Text(
          error,
          style: const TextStyle(
            color: ThemeColors.textSecondary,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      )
          : dataList.isEmpty
          ? const Center(
        child: Text(
          "Aucune information disponible pour cette année.",
          style: TextStyle(color: ThemeColors.textSecondary),
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Pilotes"),
                  selected: showPilotes,
                  onSelected: pilotesAvailable
                      ? (val) =>
                      setState(() => showPilotes = true)
                      : null,
                  disabledColor: ThemeColors.desactive,
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text("Constructeurs"),
                  selected: !showPilotes,
                  onSelected: constructorsAvailable
                      ? (val) =>
                      setState(() => showPilotes = false)
                      : null,
                  disabledColor: ThemeColors.desactive,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: dataList.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 6),
              itemBuilder: (context, index) {
                if (showPilotes) {
                  final p = pilotes[index]
                  as Map<String, dynamic>;
                  final driver =
                  (p['driver'] ?? {}) as Map<String, dynamic>;
                  final team =
                  (p['team'] ?? {}) as Map<String, dynamic>;
                  final name = _driverDisplayName(driver);
                  final key = _driverKey(driver);
                  final pos =
                  (p['position'] ?? '').toString();
                  final points =
                  (p['points'] ?? '').toString();
                  final teamName =
                  team['teamName']?.toString();

                  final isFav =
                      _favoriteDriverKey == key;

                  return Card(
                    color: ThemeColors.card,
                    elevation: 2,
                    child: ListTile(
                      leading: _buildDriverAvatar(
                        driverKey: key,
                        position:
                        int.tryParse(pos) ?? 0,
                        size: 40,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: ThemeColors.textPrimary,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: _buildTeamChip(teamName),
                      trailing: SizedBox(
                        width: 90,
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment:
                          MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                '$points pts',
                                style: TextStyle(
                                  color:
                                  ThemeColors.textPrimary,
                                  fontSize:
                                  isSmallScreen ? 12 : 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 4),
                            LikeHeart(
                              isFavorite: isFav,
                              size: isSmallScreen ? 20 : 22,
                              onToggle: () async {
                                if (isFav) {
                                  await _updateFavoriteDriver(
                                    null,
                                    null,
                                  );
                                } else {
                                  await _updateFavoriteDriver(
                                    key,
                                    name,
                                  );
                                }
                                if (!mounted) return;
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      onTap: () =>
                          handleDriverSelection(driver),
                    ),
                  );
                } else {
                  final t = constructors[index]
                  as Map<String, dynamic>;
                  final team =
                  (t['team'] ?? {}) as Map<String, dynamic>;
                  final pos =
                  (t['position'] ?? '').toString();
                  final points =
                  (t['points'] ?? '').toString();
                  final teamName =
                  team['teamName']?.toString();

                  final teamKey = _teamKey(teamName);
                  final isFavTeam =
                      _favoriteTeamKey == teamKey;

                  return Card(
                    color: ThemeColors.card,
                    elevation: 2,
                    child: ListTile(
                      leading: _buildTeamAvatar(
                        teamName,
                        pos,
                      ),
                      title: Text(
                        teamName ?? '',
                        style: TextStyle(
                          color: ThemeColors.textPrimary,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                      trailing: SizedBox(
                        width: 90,
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment:
                          MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                '$points pts',
                                style: TextStyle(
                                  color:
                                  ThemeColors.textPrimary,
                                  fontSize:
                                  isSmallScreen ? 12 : 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 4),
                            LikeHeart(
                              isFavorite: isFavTeam,
                              size: isSmallScreen ? 20 : 22,
                              onToggle: () async {
                                if (isFavTeam) {
                                  await _updateFavoriteTeam(
                                    null,
                                    null,
                                  );
                                } else {
                                  await _updateFavoriteTeam(
                                    teamKey,
                                    teamName,
                                  );
                                }
                                if (!mounted) return;
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );

  }
  Widget _buildTeamAvatar(String? teamName, String pos) {
    final key = _teamKey(teamName);
    final logo = teamLogos[key];

    if (logo == null || logo.isEmpty) {
      return CircleAvatar(child: Text(pos));
    }
    return SizedBox(
      width: 40,
      height: 40,
      child: ClipOval(
        child: Image.network(
          logo,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              CircleAvatar(child: Text(pos)),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return CircleAvatar(child: Text(pos));
          },
        ),
      ),
    );
  }
}
// —————————————————— SearchPopin (inchangée sauf import)
class SearchPopin extends StatefulWidget {
  final int minYear;
  final int? initialYear;
  final Function(Map<String, dynamic> driver)? onDriverSelected;

  const SearchPopin({
    super.key,
    required this.minYear,
    this.initialYear,
    this.onDriverSelected,
  });

  @override
  State<SearchPopin> createState() => _SearchPopinState();
}

class _SearchPopinState extends State<SearchPopin> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool loading = false;
  String error = "";
  List<dynamic> drivers = [];
  final TextEditingController searchController = TextEditingController();

  final Map<String, String?> _driverThumbs = {};
  final Set<String> _inFlightThumbs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchDrivers();
  }

  String _driverKey(Map<String, dynamic> d) {
    final name = (d["name"] ?? "").toString().trim();
    final surname = (d["surname"] ?? "").toString().trim();
    return ('$name $surname').toLowerCase();
  }

  Future<void> fetchDrivers() async {
    setState(() {
      loading = true;
      error = "";
    });

    try {
      final resp = await http.get(Uri.parse("https://f1api.dev/api/drivers?limit=1000000"));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          drivers = (data["drivers"] ?? []) as List<dynamic>;
          loading = false;
        });
      } else {
        setState(() {
          error = "Impossible de récupérer la liste des pilotes.";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Erreur lors du chargement des pilotes.";
        loading = false;
      });
    }
  }

  Future<String?> _fetchDriverImageFromWikipedia(String wikiUrl) async {
    try {
      final uri = Uri.parse(wikiUrl);
      final title = Uri.encodeComponent(uri.pathSegments.last);
      final restUrl = 'https://${uri.host}/api/rest_v1/page/summary/$title';
      final resp = await http.get(
        Uri.parse(restUrl),
        headers: {'User-Agent': 'F1StandingsApp/1.0 (contact@example.com)'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final thumb = data['thumbnail'];
        if (thumb is Map && thumb['source'] is String) return thumb['source'] as String;
      }
    } catch (_) {}

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

  Future<void> _ensureThumbFor(Map<String, dynamic> d) async {
    final key = _driverKey(d);
    if (_driverThumbs.containsKey(key) || _inFlightThumbs.contains(key)) return;

    final url = d['url'];
    if (url is! String || url.isEmpty) {
      _driverThumbs[key] = null;
      return;
    }

    _inFlightThumbs.add(key);
    try {
      final img = await _fetchDriverImageFromWikipedia(url);
      if (!mounted) return;
      setState(() => _driverThumbs[key] = img);
    } finally {
      _inFlightThumbs.remove(key);
    }
  }

  Widget _buildSearchAvatar(Map<String, dynamic> d) {
    final key = _driverKey(d);
    _ensureThumbFor(d);

    final img = _driverThumbs[key];
    const double size = 40;

    if (img == null || img.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: ThemeColors.selected,
        child: const Icon(Icons.person_outline, color: Colors.white),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          img,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return CircleAvatar(
              radius: size / 2,
              backgroundColor: ThemeColors.selected,
              child: const Icon(Icons.person_outline, color: Colors.white),
            );
          },
          errorBuilder: (_, __, ___) => CircleAvatar(
            radius: size / 2,
            backgroundColor: ThemeColors.selected,
            child: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int maxYear = DateTime.now().year;
    final years = List<int>.generate(maxYear - widget.minYear + 1, (i) => maxYear - i);
    final filteredDrivers = searchController.text.isEmpty
        ? drivers
        : drivers
        .where((d) =>
    (d["name"] ?? "").toLowerCase().contains(searchController.text.toLowerCase()) ||
        (d["surname"] ?? "").toLowerCase().contains(searchController.text.toLowerCase()))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      backgroundColor: ThemeColors.card,
      child: SizedBox(
        width: 340,
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Rechercher",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: ThemeColors.textPrimary,
              unselectedLabelColor: ThemeColors.textSecondary,
              indicatorColor: ThemeColors.selected,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_today), text: "Année"),
                Tab(icon: Icon(Icons.person), text: "Pilote"),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: years.length,
                    itemBuilder: (context, index) {
                      final year = years[index];
                      final selected = year == widget.initialYear;
                      return Material(
                        color: selected ? ThemeColors.selected : ThemeColors.card,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.pop(context, year),
                          child: Center(
                            child: Text(
                              "$year",
                              style: TextStyle(
                                color: ThemeColors.textPrimary,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  loading
                      ? const Center(child: CircularProgressIndicator())
                      : error.isNotEmpty
                      ? Center(
                    child: Text(
                      error,
                      style: const TextStyle(color: ThemeColors.textSecondary, fontSize: 16),
                    ),
                  )
                      : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TextField(
                          controller: searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: "Rechercher un pilote...",
                            filled: true,
                            fillColor: ThemeColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            hintStyle: const TextStyle(color: ThemeColors.textSecondary),
                          ),
                          style: const TextStyle(color: ThemeColors.textPrimary),
                        ),
                      ),
                      Expanded(
                        child: filteredDrivers.isEmpty
                            ? const Center(
                          child: Text(
                            "Aucun pilote trouvé.",
                            style: TextStyle(color: ThemeColors.textSecondary),
                          ),
                        )
                            : ListView.builder(
                          itemCount: filteredDrivers.length,
                          itemBuilder: (context, index) {
                            final d = filteredDrivers[index] as Map<String, dynamic>;
                            final name = "${d["name"] ?? ""} ${d["surname"] ?? ""}".trim();
                            return ListTile(
                              leading: _buildSearchAvatar(d),
                              title: Text(
                                name,
                                style: const TextStyle(color: ThemeColors.textPrimary),
                              ),
                              subtitle: Text(
                                d["nationality"]?.toString() ?? "",
                                style: const TextStyle(color: ThemeColors.textSecondary),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                if (widget.onDriverSelected != null) {
                                  widget.onDriverSelected!(d);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
