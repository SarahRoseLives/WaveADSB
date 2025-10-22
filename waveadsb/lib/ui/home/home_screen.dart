// ui/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // 1. Import MapController
import 'package:waveadsb/ui/home/bottombar.dart';
import 'package:waveadsb/ui/home/leftbar.dart';
import 'package:waveadsb/ui/home/map.dart';
import 'package:waveadsb/ui/home/rightbar.dart';
import 'package:waveadsb/ui/home/topbar.dart';

// 2. Convert to StatefulWidget to hold the controller
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 3. Create the MapController
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopBar(),
      body: Row(
        children: [
          // 4. Pass the controller to LeftSidebar
          LeftSidebar(mapController: _mapController),
          // 5. Pass the controller to MapArea
          MapArea(mapController: _mapController),
          const RightSidebar(),
        ],
      ),
      bottomNavigationBar: const BottomBar(),
    );
  }
}