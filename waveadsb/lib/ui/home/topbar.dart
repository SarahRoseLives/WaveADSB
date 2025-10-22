// ui/home/topbar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waveadsb/ui/about/about.dart'; // 1. IMPORT NEW ABOUT SCREEN
import 'package:waveadsb/ui/configure/feeds.dart';
import 'package:waveadsb/ui/configure/map.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('WaveADSB'),
      actions: [
        // --- Transmit Button (REMOVED) ---

        // --- Messages Button (REMOVED) ---

        // --- Configure Menu (Updated) ---
        PopupMenuButton<String>(
          onSelected: (String value) {
            if (value == 'ports') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConfigurePortsScreen(),
                ),
              );
            } else if (value == 'map') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConfigureMapScreen(),
                ),
              );
            }
          },
          color: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2.0),
            side: BorderSide(color: Colors.black.withOpacity(0.7), width: 1),
          ),
          offset: const Offset(0, kToolbarHeight - 12),
          tooltip: 'Configuration Options',
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            _buildPopupMenuItem(
              value: 'ports',
              text: 'Feeds', // Renamed from 'Ports'
            ),
            _buildPopupMenuItem(
              value: 'map',
              text: 'Map',
            ),
            // "Station Setup" (REMOVED)
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Configure',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),

        // --- Screen Menu (REMOVED) ---

        // 2. UPDATE 'About' BUTTON TO NAVIGATE
        _menuButton(
          'About',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AboutScreen(),
              ),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Icon(Icons.exit_to_app), // This likely does nothing, but leaving it
        ),
      ],
    );
  }

  // 3. UPDATE HELPER TO ACCEPT A CALLBACK
  Widget _menuButton(String title, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed, // Use the passed callback
      child: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required String text,
    bool enabled = true,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        text,
        style: TextStyle(
          color: enabled ? Colors.white : Colors.grey,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}