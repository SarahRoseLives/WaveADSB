// ui/screen/screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waveadsb/services/settings_service.dart';

class ScreenSettingsScreen extends StatelessWidget {
  const ScreenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Settings'),
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Show Station Lines'),
                subtitle:
                    const Text('Draw lines on the map showing the packet path'),
                value: settings.showStationLines,
                onChanged: (bool newValue) {
                  // Update the setting in the service
                  settings.updateShowStationLines(newValue);
                },
              ),
              // You can add more screen settings here later
            ],
          );
        },
      ),
    );
  }
}