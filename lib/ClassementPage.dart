import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme_colors.dart';
import 'home_page.dart';

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
    });

    try {
      final piloteResp = await http.get(
        Uri.parse('https://f1api.dev/api/$selectedYear/drivers-championship'),
      );
      final constructorResp = await http.get(
        Uri.parse('https://f1api.dev/api/$selectedYear/constructors-championship'),
      );

      if (piloteResp.statusCode == 200 && constructorResp.statusCode == 200) {
        final piloteData = json.decode(piloteResp.body);
        final constructorData = json.decode(constructorResp.body);

        final pilotesList = piloteData['drivers_championship'] ?? [];
        final constructorsList = constructorData['constructors_championship'] ?? [];

        if (pilotesList.isEmpty && constructorsList.isEmpty) {
          setState(() {
            error = "Aucune information disponible pour cette année.";
            loading = false;
          });
          return;
        }

        setState(() {
          pilotes = pilotesList;
          constructors = constructorsList;
          loading = false;
        });
      } else {
        setState(() {
          error = "Aucune information disponible pour cette année.";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Aucune information disponible pour cette année.";
        loading = false;
      });
    }
  }

  Future<void> _openSearchPopin() async {
    final chosen = await showDialog<dynamic>(
      context: context,
      builder: (context) => SearchPopin(
        minYear: 1950,
        initialYear: selectedYear,
      ),
    );

    if (chosen != null) {
      if (chosen is int) {
        setState(() => selectedYear = chosen);
        fetchData();
      } else if (chosen is Map && chosen["type"] == "driver") {
        final driver = chosen["driver"];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Pilote sélectionné : ${driver["name"]} ${driver["surname"]}"),
          ),
        );
      }
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
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      )
          : dataList.isEmpty
          ? const Center(
        child: Text(
          "Aucune information disponible pour cette année.",
          style: TextStyle(color: Colors.white70, fontSize: 16),
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
                  onSelected: (val) => setState(() => showPilotes = true),
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text("Constructeurs"),
                  selected: !showPilotes,
                  onSelected: (val) => setState(() => showPilotes = false),
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
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        team['teamName'] ?? '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: Text(
                        '${p['points']} pts',
                        style: const TextStyle(color: Colors.white),
                      ),
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
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Text(
                        '${t['points']} pts',
                        style: const TextStyle(color: Colors.white),
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

class SearchPopin extends StatefulWidget {
  final int minYear;
  final int? initialYear;

  const SearchPopin({
    super.key,
    required this.minYear,
    this.initialYear,
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
        (d["surname"] ?? "")
            .toLowerCase()
            .contains(searchController.text.toLowerCase()))
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
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Theme.of(context).colorScheme.primary,
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
                            ? Theme.of(context).colorScheme.primaryContainer
                            : ThemeColors.card,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.pop(context, year),
                          child: Center(
                            child: Text(
                              "$year",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
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
                      style:
                      const TextStyle(color: Colors.white70, fontSize: 16),
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
                            hintStyle:
                            const TextStyle(color: Colors.white54),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Expanded(
                        child: filteredDrivers.isEmpty
                            ? const Center(
                          child: Text(
                            "Aucun pilote trouvé.",
                            style:
                            TextStyle(color: Colors.white70),
                          ),
                        )
                            : ListView.builder(
                          itemCount: filteredDrivers.length,
                          itemBuilder: (context, index) {
                            final d = filteredDrivers[index];
                            final name =
                                "${d["name"] ?? ""} ${d["surname"] ?? ""}";
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child:
                                const Icon(Icons.person_outline),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                    color: Colors.white),
                              ),
                              subtitle: Text(
                                d["nationality"] ?? "",
                                style: const TextStyle(
                                    color: Colors.white54),
                              ),
                              onTap: () {
                                Navigator.pop(context, {
                                  "type": "driver",
                                  "driver": d
                                });
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
