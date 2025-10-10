import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  int selectedYear = DateTime.now().year;

  List<dynamic> pilotes = [];
  List<dynamic> constructors = [];

  bool pilotesAvailable = true;
  bool constructorsAvailable = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      loading = true;
      error = "";
      pilotes = [];
      constructors = [];
      pilotesAvailable = true;
      constructorsAvailable = true;
    });

    // ⚡ Fetch pilotes
    try {
      final piloteResp = await http.get(
        Uri.parse('https://f1api.dev/api/$selectedYear/drivers-championship'),
      );
      if (piloteResp.statusCode == 200) {
        final piloteData = json.decode(piloteResp.body);
        pilotes = piloteData['drivers_championship'] ?? [];
      } else {
        pilotes = [];
      }
    } catch (e) {
      pilotes = [];
    }

    // ⚡ Fetch constructeurs
    try {
      final constructorResp = await http.get(
        Uri.parse('https://f1api.dev/api/$selectedYear/constructors-championship'),
      );
      if (constructorResp.statusCode == 200) {
        final constructorData = json.decode(constructorResp.body);
        constructors = constructorData['constructors_championship'] ?? [];
      } else {
        constructors = [];
      }
    } catch (e) {
      constructors = [];
    }

    setState(() {
      pilotesAvailable = pilotes.isNotEmpty;
      constructorsAvailable = constructors.isNotEmpty;

      // ⚡ Basculer automatiquement si une catégorie est vide
      if (showPilotes && !pilotesAvailable) showPilotes = constructorsAvailable;
      if (!showPilotes && !constructorsAvailable) showPilotes = pilotesAvailable;

      if (!pilotesAvailable && !constructorsAvailable) {
        error = "Aucune information disponible pour cette année.";
      }

      loading = false;
    });
  }

  void showDriverDetailsPopin(BuildContext context, Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "${driver['name'] ?? ''} ${driver['surname'] ?? ''}",
          style: const TextStyle(color: ThemeColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Date de naissance : ${driver['birthday'] ?? 'N/A'}",
                style: const TextStyle(color: ThemeColors.textSecondary)),
            Text("Nationalité : ${driver['nationality'] ?? 'N/A'}",
                style: const TextStyle(color: ThemeColors.textSecondary)),
            Text("Numéro : ${driver['number'] ?? 'N/A'}",
                style: const TextStyle(color: ThemeColors.textSecondary)),
            GestureDetector(
              onTap: () {
                final url = driver['url'];
                if (url != null) {
                  // launchUrl(Uri.parse(url));
                }
              },
              child: Text(
                "Plus d'infos",
                style: TextStyle(
                    color: ThemeColors.selected,
                    decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer", style: TextStyle(color: ThemeColors.textPrimary)),
          )
        ],
      ),
    );
  }

  Future<void> handleDriverSelection(Map<String, dynamic> driver) async {
    final surname = driver['surname'] ?? '';
    final name = driver['name'] ?? '';
    if (surname.isEmpty || name.isEmpty) return;

    try {
      final resp = await http.get(Uri.parse("https://f1api.dev/api/drivers/search?q=$surname"));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final drivers = data['drivers'] ?? [];

        if (drivers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucun pilote trouvé.")),
          );
        } else {
          final matchedDriver = drivers.firstWhere(
                (d) => (d['name'] == name && d['surname'] == surname),
            orElse: () => drivers[0],
          );
          showDriverDetailsPopin(context, matchedDriver);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible de récupérer les détails du pilote.")),
        );
      }
    } catch (e) {
      print("Erreur fetchDriverDetails: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la récupération du pilote.")),
      );
    }
  }

  Future<void> _openSearchPopin() async {
    final chosen = await showDialog<dynamic>(
      context: context,
      builder: (context) => SearchPopin(
        minYear: 1950,
        initialYear: selectedYear,
        onDriverSelected: handleDriverSelection,
      ),
    );

    if (chosen != null && chosen is int) {
      setState(() => selectedYear = chosen);
      fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataList = showPilotes ? pilotes : constructors;

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
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(
        child: Text(
          error,
          style: const TextStyle(color: ThemeColors.textSecondary, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      )
          : dataList.isEmpty
          ? const Center(
        child: Text(
          "Aucune information disponible pour cette année.",
          style: TextStyle(color: ThemeColors.textSecondary, fontSize: 16),
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Pilotes"),
                  selected: showPilotes,
                  onSelected: pilotesAvailable
                      ? (val) => setState(() => showPilotes = true)
                      : null,
                  disabledColor: ThemeColors.desactive,
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text("Constructeurs"),
                  selected: !showPilotes,
                  onSelected: constructorsAvailable
                      ? (val) => setState(() => showPilotes = false)
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
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                if (showPilotes) {
                  final p = pilotes[index];
                  final driver = p['driver'] ?? {};
                  final team = p['team'] ?? {};
                  return Card(
                    color: ThemeColors.card,
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${p['position']}')),
                      title: Text(
                        '${driver['name'] ?? ''} ${driver['surname'] ?? ''}',
                        style: const TextStyle(color: ThemeColors.textPrimary),
                      ),
                      subtitle: Text(
                        team['teamName'] ?? '',
                        style: const TextStyle(color: ThemeColors.textSecondary),
                      ),
                      trailing: Text(
                        '${p['points']} pts',
                        style: const TextStyle(color: ThemeColors.textPrimary),
                      ),
                      onTap: () => handleDriverSelection(driver),
                    ),
                  );
                } else {
                  final t = constructors[index];
                  final team = t['team'] ?? {};
                  return Card(
                    color: ThemeColors.card,
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${t['position']}')),
                      title: Text(
                        team['teamName'] ?? '',
                        style: const TextStyle(color: ThemeColors.textPrimary),
                      ),
                      trailing: Text(
                        '${t['points']} pts',
                        style: const TextStyle(color: ThemeColors.textPrimary),
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
}

// --------------------- SearchPopin ---------------------

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
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchDrivers();
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
          drivers = data["drivers"] ?? [];
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
              labelColor: ThemeColors.blanc,
              unselectedLabelColor: ThemeColors.gris,
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
                        color: selected
                            ? ThemeColors.selected
                            : ThemeColors.card,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.pop(context, year),
                          child: Center(
                            child: Text(
                              "$year",
                              style: TextStyle(
                                color: ThemeColors.blanc,
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
                            hintStyle: const TextStyle(color: ThemeColors.gris),
                          ),
                          style: const TextStyle(color: ThemeColors.blanc),
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
                            final d = filteredDrivers[index];
                            final name = "${d["name"] ?? ""} ${d["surname"] ?? ""}";
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: ThemeColors.selected,
                                child: const Icon(Icons.person_outline),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(color: ThemeColors.textPrimary),
                              ),
                              subtitle: Text(
                                d["nationality"] ?? "",
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
