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
    });

    try {
      final piloteResp = await http.get(
        Uri.parse('https://f1api.dev/api/current/drivers-championship'),
      );
      final constructorResp = await http.get(
        Uri.parse('https://f1api.dev/api/current/constructors-championship'),
      );

      if (piloteResp.statusCode == 200 && constructorResp.statusCode == 200) {
        final piloteData = json.decode(piloteResp.body);
        final constructorData = json.decode(constructorResp.body);

        setState(() {
          pilotes = piloteData['drivers_championship'] ?? [];
          constructors = constructorData['constructors_championship'] ?? [];
          loading = false;
        });
      } else {
        setState(() {
          error =
          "Erreur HTTP : pilotes ${piloteResp.statusCode}, constructeurs ${constructorResp.statusCode}";
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Erreur : $e";
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      appBar: AppBar(
        title: const Text("🏆 Classement F1 2025"),
        backgroundColor: ThemeColors.appBar,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(child: Text(error, style: const TextStyle(color: Colors.red)))
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
              itemCount: showPilotes ? pilotes.length : constructors.length,
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
                      title: Text('${driver['name'] ?? ''} ${driver['surname'] ?? ''}',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(team['teamName'] ?? '',
                          style: const TextStyle(color: Colors.white70)),
                      trailing: Text('${p['points']} pts',
                          style: const TextStyle(color: Colors.white)),
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
                      title: Text(team['teamName'] ?? '',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: const Text(''),
                      trailing: Text('${t['points']} pts',
                          style: const TextStyle(color: Colors.white)),
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
