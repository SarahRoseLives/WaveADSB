// ui/configure/map.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // 1. IMPORT for LatLngBounds and TileLayer
import 'package:latlong2/latlong.dart'; // 2. IMPORT for Distance
import 'package:provider/provider.dart';
import 'package:waveadsb/services/settings_service.dart';
// 3. IMPORT TILE CACHING
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

class ConfigureMapScreen extends StatelessWidget {
  const ConfigureMapScreen({super.key});

  // 4. HELPER TO SHOW A SNACKBAR
  void _showSnackbar(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : Colors.blueGrey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Settings'),
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Show Flight Paths'),
                subtitle: const Text(
                    'Draw a line on the map showing the aircraft\'s path'),
                value: settings.showFlightPaths,
                onChanged: (bool newValue) {
                  // Update the setting in the service
                  settings.updateShowFlightPaths(newValue);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Offline Mode'),
                subtitle:
                    const Text('Use downloaded map tiles (if available)'),
                value: settings.offlineMode,
                onChanged: (bool newValue) {
                  settings.updateOfflineMode(newValue);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline),
                title: const Text('Download Map for Offline Use'),
                subtitle: const Text(
                    'Download a 50 NM radius around your home location'),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  // 5. IMPLEMENT ONPRESSED LOGIC
                  onPressed: () async {
                    if (settings.homeLocation == null) {
                      _showSnackbar(context, 'Please set a home location on the map first.', error: true);
                      return;
                    }

                    _showSnackbar(context, 'Starting download... This may take a while.');

                    try {
                      // Calculate the bounding box for 50 NM (92600 meters)
                      const Distance distance = Distance();
                      final LatLng northEast = distance.offset(
                          settings.homeLocation!, 92600, 45); // 45 degrees
                      final LatLng southWest = distance.offset(
                          settings.homeLocation!, 92600, 225); // 225 degrees

                      final LatLngBounds bounds =
                          LatLngBounds(northEast, southWest);

                      // FIX: Create DownloadableRegion first
                      final downloadableRegion = RectangleRegion(bounds).toDownloadable(
                        minZoom: 1,
                        maxZoom: 12,
                        // Provide dummy TileLayer options needed by toDownloadable
                        options: TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.waveadsb', // Needs a package name
                        ),
                        // Optionally set start/end if resuming partial downloads
                        // start: 1,
                        // end: null,
                      );

                      // Start the download using the DownloadableRegion
                      await FMTCStore('default').download.startForeground(
                        region: downloadableRegion, // Pass the created region
                        // REMOVE minZoom/maxZoom, they are in the region now
                        // skipExistingTiles: false, // Example: add other options if desired
                      );

                      _showSnackbar(context, 'Offline map download complete!');
                    } catch (e, s) { // Catch stack trace for better debugging
                      print('Download Error: $e\n$s'); // Print stack trace
                      _showSnackbar(context, 'Download failed: $e', error: true);
                    }
                  },
                ),
              ),
              // 6. ADD A "CLEAR CACHE" BUTTON
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red[400]),
                title: Text('Clear Tile Cache',
                    style: TextStyle(color: Colors.red[400])),
                subtitle: const Text('Delete all downloaded map tiles'),
                onTap: () async {
                  try {
                    // FIX: Use 'FMTCStore'
                    await FMTCStore('default').manage.reset();
                    _showSnackbar(context, 'Tile cache cleared.');
                  } catch (e, s) { // Catch stack trace
                    print('Cache Clear Error: $e\n$s'); // Print stack trace
                    _showSnackbar(context, 'Failed to clear cache: $e', error: true);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}