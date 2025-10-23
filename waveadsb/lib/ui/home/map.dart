// ui/home/map.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:waveadsb/models/aircraft.dart';
import 'package:waveadsb/services/adsb_service.dart';
import 'package:waveadsb/services/settings_service.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math; // For marker rotation
// 1. IMPORT TILE CACHING
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

// Define a default center point
const LatLng defaultCenter =
    LatLng(41.4993, -81.6944); // Cleveland as a center point

class MapArea extends StatefulWidget {
  final MapController mapController;
  const MapArea({required this.mapController, super.key});

  @override
  State<MapArea> createState() => _MapAreaState();
}

class _MapAreaState extends State<MapArea> {
  bool _hasAutoCentered = false;

  // REMOVED: TileProvider is now created inside build

  @override
  void initState() {
    super.initState();
    // REMOVED: Initialization moved to build
  }


  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final adsbService = context.watch<AdsbService>();
    final aircraftList = adsbService.aircraft;
    final homeLoc = settings.homeLocation;

    // --- 4. Auto-center logic (Unchanged) ---
    if (!_hasAutoCentered && aircraftList.isNotEmpty) {
      final aircraftWithPosition = aircraftList.where((ac) => ac.hasPosition);
      final Aircraft? firstAircraft =
          aircraftWithPosition.isEmpty ? null : aircraftWithPosition.first;

      if (firstAircraft != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print("Auto-centering on first aircraft: ${firstAircraft.icao}");
            widget.mapController.move(firstAircraft.position!, 10.0);
          }
        });
        _hasAutoCentered = true;
      }
    }

    // --- Build Markers (Unchanged) ---
    final List<Marker> aircraftMarkers = aircraftList
        .where((ac) => ac.hasPosition)
        .map((aircraft) {
      return Marker(
        point: aircraft.position!,
        width: 80,
        height: 60,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            _showAircraftDetailsDialog(context, aircraft);
          },
          child: _buildAircraftMarker(aircraft),
        ),
      );
    }).toList();

    // --- Add Home Marker if set (Unchanged) ---
    if (homeLoc != null) {
      aircraftMarkers.add(
        Marker(
          point: homeLoc,
          width: 80,
          height: 60,
          alignment: Alignment.center,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_pin,
                  color: Colors.red[400],
                  size: 30,
                  shadows: const [Shadow(blurRadius: 2.0, color: Colors.black)],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'HOME',
                    style: TextStyle(
                        color: Colors.red[400],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(
                              blurRadius: 1.0,
                              color: Colors.black,
                              offset: Offset(1, 1))
                        ]),
                  ),
                ),
              ]),
        ),
      );
    }

    // --- 5. Build Flight Paths (Unchanged) ---
    final List<Polyline> flightPaths = [];
    if (settings.showFlightPaths) {
      for (final aircraft in aircraftList) {
        if (aircraft.pathHistory.length > 1) {
          flightPaths.add(
            Polyline(
              points: aircraft.pathHistory,
              color: Colors.cyan.withOpacity(0.6),
              strokeWidth: 2.0,
            ),
          );
        }
      }
    }

    // --- FIX: Create TileProvider inside build ---
    final tileProvider = FMTCTileProvider.allStores(
        // FIX: Use a valid BrowseStoreStrategy
        allStoresStrategy: BrowseStoreStrategy.readUpdateCreate, // Use readUpdateCreate or similar
        loadingStrategy: settings.offlineMode
            ? BrowseLoadingStrategy.cacheOnly
            : BrowseLoadingStrategy.cacheFirst,
    );


    // --- Main Map Widget ---
    return Expanded(
      child: FlutterMap(
        mapController: widget.mapController,
        options: MapOptions(
          initialCenter: homeLoc ?? defaultCenter,
          initialZoom: 9.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onSecondaryTap: (tapPosition, latLng) {
            settings.updateHomeLocation(latLng);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Home location set to ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}'),
                backgroundColor: Colors.green,
              ),
            );
          },
          onLongPress: (tapPosition, latLng) {
            settings.updateHomeLocation(latLng);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Home location set to ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.waveadsb',
            // Use the TileProvider created above
            tileProvider: tileProvider,
            // Pass TileLayer options needed by toDownloadable if creating region inside build
            // options: TileLayerOptions(...), // Example if needed later
          ),
          if (homeLoc != null)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: homeLoc,
                  radius: 92600, // 50 NM in meters
                  useRadiusInMeter: true,
                  color: Colors.white.withOpacity(0.1),
                  borderColor: Colors.white.withOpacity(0.4),
                  borderStrokeWidth: 1,
                ),
                CircleMarker(
                  point: homeLoc,
                  radius: 185200, // 100 NM in meters
                  useRadiusInMeter: true,
                  color: Colors.white.withOpacity(0.05),
                  borderColor: Colors.white.withOpacity(0.3),
                  borderStrokeWidth: 1,
                ),
              ],
            ),
          // 6. Add the PolylineLayer (Unchanged)
          if (settings.showFlightPaths)
            PolylineLayer(polylines: flightPaths),
          MarkerLayer(
            markers: aircraftMarkers,
          ),
        ],
      ),
    );
  }

  // --- Helper methods (all unchanged) ---
  Widget _buildAircraftMarker(Aircraft aircraft) {
    final heading = aircraft.track ?? 0;
    final color = Colors.cyan[400]!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.rotate(
          angle: heading * (math.pi / 180), // Convert degrees to radians
          child: Icon(
            Icons.airplanemode_active,
            color: color,
            size: 24,
            shadows: const [Shadow(blurRadius: 2.0, color: Colors.black)],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            aircraft.callsign ?? aircraft.icao,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(
                      blurRadius: 1.0,
                      color: Colors.black,
                      offset: Offset(1, 1))
                ]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showAircraftDetailsDialog(BuildContext context, Aircraft aircraft) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedTimestamp = formatter.format(aircraft.lastUpdated);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: Text(aircraft.callsign ?? aircraft.icao,
              style: TextStyle(color: Colors.cyan[400])),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDetailRow('ICAO:', aircraft.icao),
                _buildDetailRow('Altitude:',
                    '${aircraft.altitude ?? 'N/A'} ft'),
                _buildDetailRow(
                    'Speed:', '${aircraft.groundSpeed ?? 'N/A'} kts'),
                _buildDetailRow('Heading:', '${aircraft.track ?? 'N/A'}°'),
                if (aircraft.position != null)
                  _buildDetailRow('Position:',
                      '${aircraft.position!.latitude.toStringAsFixed(4)}, ${aircraft.position!.longitude.toStringAsFixed(4)}'),
                _buildDetailRow('Last Heard:', formattedTimestamp),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool wrap = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment:
            wrap ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}