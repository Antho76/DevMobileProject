import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:auto_size_text/auto_size_text.dart';

class GrandPrixListPage extends StatefulWidget {
  const GrandPrixListPage({super.key});

  @override
  State<GrandPrixListPage> createState() => _GrandPrixListPageState();
}

Future<String?> fetchIsoCodeFromRestCountries(String countryName) async {
  try {
    final url = Uri.parse('https://restcountries.com/v3.1/name/$countryName');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      if (data.isNotEmpty && data[0]['cca2'] != null) {
        return data[0]['cca2']; // ex: "FR"
      }
    }
  } catch (e) {
    print('Erreur API REST Countries: $e');
  }
  return null;
}


/// 🔹 Découpe en forme d’arc sur la GAUCHE
class LeftCutClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double radius = 24;

    final path = Path();
    path.moveTo(size.width,0);
    path.lineTo(size.width, size.height);
    path.lineTo(0,size.height);

    // Arc inversé sur la gauche
    path.arcToPoint(
      Offset(0, 0),
      radius: const Radius.circular(radius),
      clockwise: false,
    );

    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _GrandPrixListPageState extends State<GrandPrixListPage> {
  late Future<List<dynamic>> _racesFuture;

  @override
  void initState() {
    super.initState();
    _racesFuture = fetchRaces();
  }

  Future<List<dynamic>> fetchRaces() async {
    final url = Uri.parse('https://f1api.dev/api/current');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['races'] ?? [];
    } else {
      throw Exception('Erreur API F1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        title: const Text(
          "🗓️ Calendrier F1 2025",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF1A1A1A),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _racesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Erreur : ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final races = snapshot.data ?? [];

          races.sort((a, b) {
            final dateA = DateTime.parse(a['schedule']['race']['date']);
            final dateB = DateTime.parse(b['schedule']['race']['date']);
            return dateA.compareTo(dateB);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: races.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16), // <-- espace entre chaque carte
            itemBuilder: (context, index) {
              final race = races[index];
              final raceDate = DateTime.parse(race['schedule']['race']['date']);
              final formattedDate =
              DateFormat('d MMMM yyyy', 'fr_FR').format(raceDate);

              final country = race['circuit']?['country'] ?? 'Pays inconnu';

              final city = race['circuit']?['city'] ?? '';
              final raceName = race['raceName'] ?? 'Grand Prix';
              final url = race['url'];
              final mainCardWidth = isMobile? screenWidth*0.75 : screenWidth * 0.4;
              final dateBannerWidth = isMobile? mainCardWidth*0.75 : 360.0;

              return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🟣 Losange violet (en dehors du bloc)
                  Transform.translate(
                    offset: isMobile? const Offset(5, 0) : const Offset(40,0),
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Transform.rotate(
                          angle: -math.pi / 4,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: isMobile? const Offset(-28, 0) : const Offset(0,0),

                  child : SizedBox(
                    width: mainCardWidth, // 75% de la largeur écran
                    child: ClipPath(
                      clipper: LeftCutClipper(),
                      child: Container(
                        padding: const EdgeInsets.only(left: 32, right: 12, top: 8, bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F1F2E),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipPath(
                              clipper: LeftCutClipper(),
                              child: Container(
                                width: dateBannerWidth,
                                padding: const EdgeInsets.only(left: 32, right: 12, top: 8, bottom: 8),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFFF914D),
                                      Color(0xFFFFC371)
                                    ],
                                  ),
                                ),
                                child: Text(
                                  formattedDate.toUpperCase(),
                                  textAlign: TextAlign.start,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.only(left: 32, right: 12, top: 8, bottom: 8),

                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        FutureBuilder<String?>(
                                          future: fetchIsoCodeFromRestCountries(country),
                                          builder: (context, snapshot) {
                                            final isoCode = snapshot.data?.toLowerCase();

                                            return Row(
                                              children: [
                                                if (snapshot.connectionState == ConnectionState.waiting)
                                                  const SizedBox(width: 32, height: 24),
                                                if (isoCode != null)
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Image.network(
                                                      "https://flagcdn.com/48x36/$isoCode.png",
                                                      width: 32,
                                                      height: 24,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) =>
                                                      const SizedBox(width: 32, height: 24),
                                                    ),
                                                  ),
                                                const SizedBox(width: 8),
                                                ConstrainedBox(
                                                  constraints: BoxConstraints(maxWidth: screenWidth * 0.3),
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment: Alignment.centerLeft,
                                                    child: Text(
                                                      country.toUpperCase(),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 18,
                                                  ),
                                                ),
                                                ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),

                                        const SizedBox(height: 4),
                                        Text(
                                          city,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.route,
                                      color: Colors.orangeAccent, size: 28),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ),
                ],
              ),
              );
            },
          );
        },
      ),
    );
  }
}
