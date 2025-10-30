// ui/home/leftbar.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:waveadsb/models/aircraft.dart';
import 'package:waveadsb/models/message.dart'; // 1. IMPORT MESSAGE
import 'package:waveadsb/services/adsb_service.dart';
import 'package:intl/intl.dart'; // 2. IMPORT INTL FOR DATE FORMATTING

// 3. CONVERT TO STATEFULWIDGET
class LeftSidebar extends StatefulWidget {
  final MapController mapController;
  const LeftSidebar({required this.mapController, super.key});

  @override
  State<LeftSidebar> createState() => _LeftSidebarState();
}

// 4. ADD SingleTickerProviderStateMixin
class _LeftSidebarState extends State<LeftSidebar>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _timeFormat =
      DateFormat('HH:mm:ss'); // 5. For ACARS timestamp

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 6. Init controller
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Consume the new AdsbService
    final adsbService = context.watch<AdsbService>();
    final aircraftList = adsbService.aircraft;
    final acarsMessages =
        adsbService.acarsMessages.reversed.toList(); // 7. GET MESSAGES
    final status = adsbService.status;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF252526),
        border: Border(
          right: BorderSide(color: Colors.black.withOpacity(0.5), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 0),
            child: Text(
              status,
              style: TextStyle(
                color: status.startsWith('Connected') ||
                        status.startsWith('Listening')
                    ? Colors.green[400]
                    : Colors.yellow[400],
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 8. ADD TABBAR
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.cyanAccent,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(
                child: Text('Aircraft (${aircraftList.length})',
                    style: const TextStyle(fontSize: 12)),
              ),
              Tab(
                child: Text('ACARS (${acarsMessages.length})',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const Divider(height: 1),
          // 9. ADD TABBARVIEW
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // --- AIRCRAFT LIST (Child 1) ---
                ListView.builder(
                  itemCount: aircraftList.length,
                  itemBuilder: (context, index) {
                    final aircraft = aircraftList[index];
                    // Pass the aircraft data to the tile builder
                    return _buildAircraftTile(aircraft);
                  },
                ),
                // --- ACARS MESSAGE LIST (Child 2) ---
                ListView.builder(
                  itemCount: acarsMessages.length,
                  itemBuilder: (context, index) {
                    final message = acarsMessages[index];
                    return _buildAcarsMessageTile(message);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single item for the aircraft list
  Widget _buildAircraftTile(Aircraft aircraft) {
    final icon = Icons.airplanemode_active;
    final color = Colors.cyan[400]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (aircraft.position != null) {
            widget.mapController.move(
              aircraft.position!,
              widget.mapController.camera.zoom > 10
                  ? widget.mapController.camera.zoom
                  : 10.0,
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.black.withOpacity(0.3), width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aircraft.callsign ?? aircraft.icao,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Alt: ${aircraft.altitude ?? 'N/A'} ft | Spd: ${aircraft.groundSpeed ?? 'N/A'} kts',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 10. NEW TILE BUILDER FOR ACARS MESSAGES
  Widget _buildAcarsMessageTile(Message message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.3), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                message.callsign,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                _timeFormat.format(message.timestamp.toLocal()),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.text,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontFamily: 'monospace', // Good for ACARS text
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}