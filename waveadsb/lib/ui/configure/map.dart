// ui/configure/map.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waveadsb/services/settings_service.dart';

class ConfigureMapScreen extends StatelessWidget {
  const ConfigureMapScreen({super.key});

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
                subtitle:
                    const Text('Download map tiles for the current map view'),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () {
                    // This is a placeholder. Implementing this is very complex
                    // and requires new packages for tile caching.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Offline map download not yet implemented.'),
                        backgroundColor: Colors.blueGrey,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}