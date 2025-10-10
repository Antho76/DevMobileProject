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

        // Si les deux sont vides → considérer comme "aucune info"
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

  /// Ouvre la pop-in pour choisir une année
  Future<void> _openYearPicker() async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => YearPickerPopin(
        minYear: 1950,
        initialYear: selectedYear,
      ),
    );

    if (chosen != null && chosen != selectedYear) {
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
            tooltip: "Rechercher par année",
            onPressed: _openYearPicker,
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
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Pilotes"),
                  selected: showPilotes,
                  onSelected: (val) =>
                      setState(() => showPilotes = true),
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text("Constructeurs"),
                  selected: !showPilotes,
                  onSelected: (val) =>
                      setState(() => showPilotes = false),
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
                  final p = pilotes[index];
                  final driver = p['driver'] ?? {};
                  final team = p['team'] ?? {};
                  return Card(
                    color: ThemeColors.card,
                    elevation: 2,
                    child: ListTile(
                      leading:
                      CircleAvatar(child: Text('${p['position']}')),
                      title: Text(
                        '${driver['name'] ?? ''} ${driver['surname'] ?? ''}',
                        style:
                        const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(team['teamName'] ?? '',
                          style: const TextStyle(
                              color: Colors.white70)),
                      trailing: Text('${p['points']} pts',
                          style: const TextStyle(
                              color: Colors.white)),
                    ),
                  );
                } else {
                  final t = constructors[index];
                  final team = t['team'] ?? {};
                  return Card(
                    color: ThemeColors.card,
                    elevation: 2,
                    child: ListTile(
                      leading:
                      CircleAvatar(child: Text('${t['position']}')),
                      title: Text(team['teamName'] ?? '',
                          style: const TextStyle(
                              color: Colors.white)),
                      trailing: Text('${t['points']} pts',
                          style: const TextStyle(
                              color: Colors.white)),
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

/// Pop-in pour choisir une année entre [minYear] et maintenant
class YearPickerPopin extends StatelessWidget {
  final int minYear;
  final int? initialYear;

  const YearPickerPopin({
    super.key,
    required this.minYear,
    this.initialYear,
  });

  @override
  Widget build(BuildContext context) {
    final int maxYear = DateTime.now().year;
    final years = List<int>.generate(maxYear - minYear + 1, (i) => maxYear - i);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      backgroundColor: ThemeColors.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Choisir une année",
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
          const Divider(height: 1),
          Flexible(
            child: SizedBox(
              height: 300,
              width: 300,
              child: GridView.builder(
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
                  final selected = year == initialYear;
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
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
