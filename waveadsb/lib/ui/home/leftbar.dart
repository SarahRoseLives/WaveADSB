// ui/home/leftbar.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:waveadsb/models/aircraft.dart';
import 'package:waveadsb/services/adsb_service.dart';

class LeftSidebar extends StatelessWidget {
  final MapController mapController;
  const LeftSidebar({required this.mapController, super.key});

  @override
  Widget build(BuildContext context) {
    // Consume the new AdsbService
    final adsbService = context.watch<AdsbService>();
    final aircraftList = adsbService.aircraft;
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
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: status.startsWith('Connected')
                        ? Colors.green[400]
                        : Colors.yellow[400],
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tracking: ${aircraftList.length}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: aircraftList.length,
              itemBuilder: (context, index) {
                final aircraft = aircraftList[index];
                // Pass the aircraft data to the tile builder
                return _buildAircraftTile(aircraft);
              },
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
            mapController.move(
              aircraft.position!,
              mapController.camera.zoom > 10 ? mapController.camera.zoom : 10.0,
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
}