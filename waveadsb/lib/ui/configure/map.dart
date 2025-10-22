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
              // You can add more map settings here later
            ],
          );
        },
      ),
    );
  }
}