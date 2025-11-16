import 'package:flutter/material.dart';
import 'footer.dart';
import 'ClassementPage.dart';
import 'home_page.dart';
import 'course_Page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'circuit_map_page.dart';
import 'theme_colors.dart';
import 'map.dart';
import 'PreferencesPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future <void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  final prefs = await SharedPreferences.getInstance();

  final hasDriver = prefs.containsKey("favorite_driver");
  final hasTeam = prefs.containsKey("favorite_team");

  final shouldShowPreferences = !(hasDriver && hasTeam);
  runApp(MyApp(showPreferences: shouldShowPreferences));

}

class MyApp extends StatelessWidget {
  final bool showPreferences;
  const MyApp({super.key, required this.showPreferences});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'F1 App',
      theme: ThemeData(
        primaryColor: ThemeColors.primary,
        scaffoldBackgroundColor: ThemeColors.background,
        brightness: Brightness.dark,
      ),
      home: showPreferences ? const PreferencesPage() : const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;


  final List<Widget> _pages = const [
    HomePage(),
    ClassementPage(),
    GrandPrixListPage(),
    MapScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Footer(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
