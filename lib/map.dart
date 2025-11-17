import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:http/http.dart' as http;
import 'theme_colors.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController controller;
  bool loading = true;
  List<Map<String, dynamic>> races = [];

  @override
  void initState() {
    super.initState();
    controller = MapController(
      initPosition: GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
      areaLimit: const BoundingBox(
        east: 10.4922941,
        north: 47.8084648,
        south: 45.817995,
        west: 5.9559113,
      ),
    );
    loadRaces();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> loadRaces() async {
    try {
      final response = await http.get(Uri.parse('https://f1api.dev/api/current'));
      if (response.statusCode != 200) {
        print('Erreur API F1: ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body);
      final List rawRaces = data['races'] ?? [];
      List<Map<String, dynamic>> tempRaces = [];

      for (var race in rawRaces) {
        final circuitData = race['circuit'];
        if (circuitData == null) continue;

        final circuit = circuitData['circuitName'] ?? '';
        final city = circuitData['city'] ?? '';
        final country = circuitData['country'] ?? '';
        final date = race['schedule']['race']['date'];

        final coords = await getCoordinates(circuit, city, country);
        if (coords != null) {
          tempRaces.add({
            'name': race['raceName'] ?? '',
            'circuit': circuit,
            'city': city,
            'country': country,
            'date': date,
            'lat': coords['lat'],
            'lng': coords['lng'],
          });
        }
      }

      setState(() {
        races = tempRaces;
        loading = false;
      });

      for (var race in races) {
        await controller.addMarker(
          GeoPoint(latitude: race['lat'], longitude: race['lng']),
          markerIcon: MarkerIcon(
            icon: Icon(Icons.location_on, color: Colors.red, size: 48),
          ),
        );
      }
    } catch (e) {
      print('Erreur: $e');
    }
  }


  Future<Map<String, double>?> getCoordinates(String circuit, String city, String country) async {
    final query = Uri.encodeComponent("$circuit, $city, $country");
    final url = Uri.parse("https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1");
    final response = await http.get(url, headers: {'User-Agent': 'FlutterApp'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        return {
          'lat': double.parse(data[0]['lat']),
          'lng': double.parse(data[0]['lon']),
        };
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: ThemeColors.background,
        appBar: AppBar(
          title: const Text("🗺️ Circuits"),
          backgroundColor: ThemeColors.appBar,
          centerTitle: true,
        ),
      body: Stack(
        children: [
          OSMFlutter(
            controller: controller,
            osmOption: OSMOption(
              userTrackingOption: const UserTrackingOption(
                enableTracking: true,
                unFollowUser: false,
              ),
              zoomOption: ZoomOption(
                initZoom: 2,
                minZoomLevel: 2,
                maxZoomLevel: 19,
                stepZoom: 1.0,
              ),
              userLocationMarker: UserLocationMaker(
                personMarker: const MarkerIcon(
                  icon: Icon(
                    Icons.location_history_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                directionArrowMarker: const MarkerIcon(
                  icon: Icon(
                    Icons.double_arrow,
                    size: 48,
                  ),
                ),
              ),
            ),
            onGeoPointClicked: (geoPoint) {
              final race = races.firstWhere((r) =>
              r['lat'] == geoPoint.latitude && r['lng'] == geoPoint.longitude);
              String formattedDate = "Date inconnue";
              if (race['date'] != null) {
                final date = DateTime.parse(race['date']);
                formattedDate =
                "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
              }
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(race['name']),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${race['circuit']}"),
                      Text("${race['city']}, ${race['country']}"),
                      const SizedBox(height: 8),
                      Text("📅 Date : $formattedDate"),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        "Fermer",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              );

            },
          ),
          if (loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await controller.currentLocation();
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}