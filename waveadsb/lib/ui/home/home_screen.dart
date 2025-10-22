// ui/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:waveadsb/ui/home/bottombar.dart';
import 'package:waveadsb/ui/home/leftbar.dart';
import 'package:waveadsb/ui/home/map.dart';
import 'package:waveadsb/ui/home/rightbar.dart';
import 'package:waveadsb/ui/home/topbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  // 1. Create a ValueNotifier to hold the current zoom
  final ValueNotifier<double> _currentZoom = ValueNotifier<double>(9.0);

  @override
  void initState() {
    super.initState();
    // 2. Listen to map events to update the zoom notifier
    _mapController.mapEventStream.listen((MapEvent event) {
      // Check for any event that might change zoom
      if (event is MapEventWithMove || event is MapEventRotate) {
        // Update the notifier's value if it has changed
        if (_currentZoom.value != event.camera.zoom) {
          _currentZoom.value = event.camera.zoom;
        }
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _currentZoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopBar(),
      body: Row(
        children: [
          LeftSidebar(mapController: _mapController),
          MapArea(mapController: _mapController),
          // 3. Pass the controller and notifier to the RightSidebar
          //    (Removed the 'const' keyword)
          RightSidebar(
            mapController: _mapController,
            zoomNotifier: _currentZoom,
          ),
        ],
      ),
      bottomNavigationBar: const BottomBar(),
    );
  }
}