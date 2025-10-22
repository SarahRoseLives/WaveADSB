// services/adsb_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart'; // 1. IMPORT LATLNG
import 'package:waveadsb/models/aircraft.dart';
import 'package:waveadsb/models/port_config.dart';
import 'package:waveadsb/services/settings_service.dart';

class AdsbService with ChangeNotifier {
  SettingsService _settingsService;

  // --- Aircraft Data ---
  final Map<String, Aircraft> _aircraft = {};
  List<Aircraft> get aircraft =>
      _aircraft.values.sorted((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

  // --- Connection Status & Management ---
  final List<String> _statusMessages = ['Not connected'];
  String get status => _statusMessages.firstOrNull ?? 'Idle';
  final List<Socket> _activeSockets = [];
  final Map<String, bool> _portConnectionDesired = {};
  Timer? _pruneTimer;

  AdsbService(this._settingsService) {
    connectToFeeds();
    _pruneTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _pruneOldAircraft();
    });
  }

  @override
  void dispose() {
    _pruneTimer?.cancel();
    for (final socket in _activeSockets) {
      socket.destroy();
    }
    super.dispose();
  }

  // Helper to update status and notify listeners
  void _updateStatus(String? add, {String? remove}) {
    if (remove != null) {
      _statusMessages.removeWhere((m) => m.startsWith(remove));
    }
    if (add != null) {
      _statusMessages.insert(0, add);
    }
    // This is a UI-facing change, so notify
    notifyListeners();
  }

  /// Public method to be called when settings change
  void updateSettings(SettingsService newSettings) {
    // Check if port settings actually changed
    if (!const DeepCollectionEquality()
        .equals(_settingsService.ports, newSettings.ports)) {
      _settingsService = newSettings;
      connectToFeeds(); // Reconnect if ports are different
    }
    _settingsService = newSettings;
  }

  // Main connection trigger/reset
  void connectToFeeds() {
    print('ADSB Service: Re-evaluating connections...');
    for (final key in _portConnectionDesired.keys) {
      _portConnectionDesired[key] = false;
    }
    for (final socket in _activeSockets) {
      socket.destroy();
    }
    _activeSockets.clear();
    _statusMessages.clear();
    final portsToConnect = _settingsService.ports;
    if (portsToConnect.isEmpty) {
      _statusMessages.add('No feeds configured.');
      notifyListeners();
      return;
    }
    for (final port in portsToConnect) {
      String portId = port.name;
      _portConnectionDesired[portId] = true;
      _managePortConnection(port);
    }
  }

  // Persistent connection loop for one port
  Future<void> _managePortConnection(PortConfig port) async {
    String portId = port.name;
    while (_portConnectionDesired[portId] == true) {
      Socket? socket;
      try {
        _updateStatus('Connecting to ${port.name}...',
            remove: 'Failed to connect: ${port.name}');
        socket = await Socket.connect(port.host, port.port,
            timeout: const Duration(seconds: 5));
        _activeSockets.add(socket);
        _updateStatus('Connected: ${port.name}',
            remove: 'Connecting to ${port.name}');

        // --- FIX 1: Use utf8.decoder.bind() ---
        // This correctly binds the decoder (a Converter) to the socket stream
        // and returns a new Stream<String>, which LineSplitter can use.
        utf8.decoder.bind(socket).transform(const LineSplitter()).listen(
          (String line) {
            _parseSbsMessage(line);
          },
          onDone: () {
            _updateStatus('Disconnected: ${port.name}',
                remove: 'Connected: ${port.name}');
          },
          onError: (e) {
            _updateStatus('Socket Error (${port.name}): $e',
                remove: 'Connected: ${port.name}');
          },
          cancelOnError: true,
        );

        await socket.done; // Wait here until socket closes or errors
      } catch (e) {
        _updateStatus('Failed to connect: ${port.name}. Retrying in 10s...',
            remove: 'Connecting to ${port.name}');
      }

      // Cleanup after connection attempt (success or fail)
      if (socket != null) {
        _activeSockets.remove(socket);
        socket.destroy();
      }

      // Wait before retrying connection, if still desired
      if (_portConnectionDesired[portId] == true) {
        await Future.delayed(const Duration(seconds: 10));
      }
    } // End while loop

    // Loop exited, clean up status messages for this port
    print('Stopping connection manager for ${port.name}');
    _updateStatus('Stopped: ${port.name}',
        remove: 'Connecting to ${port.name}');
    _updateStatus(null, remove: 'Failed to connect: ${port.name}');
    _updateStatus(null, remove: 'Disconnected: ${port.name}');
    _updateStatus(null, remove: 'Connected: ${port.name}');
  }

  /// Parses a single SBS-1 (BaseStation) message line.
  void _parseSbsMessage(String message) {
    final parts = message.split(',');
    if (parts.length < 11 || parts[0] != 'MSG') {
      return; // Not a valid message
    }

    final messageType = parts[1];
    final icao = parts[4].toUpperCase();
    if (icao.isEmpty) {
      return; // No ICAO, can't track
    }

    // Get the existing aircraft or create a new one
    final aircraft = _aircraft.putIfAbsent(icao, () => Aircraft(icao));
    bool updated = false;

    try {
      switch (messageType) {
        case '1': // Callsign
          if (parts.length >= 11) {
            final callsign = parts[10].trim();
            if (callsign.isNotEmpty) {
              aircraft.callsign = callsign;
              updated = true;
            }
          }
          break;
        case '3': // Airborne Position
          if (parts.length >= 16 &&
              parts[14].isNotEmpty &&
              parts[15].isNotEmpty) {
            // 2. Parse lat/lon
            final lat = double.tryParse(parts[14]);
            final lon = double.tryParse(parts[15]);

            if (lat != null && lon != null) {
              aircraft.altitude = int.tryParse(parts[11]);
              aircraft.latitude = lat;
              aircraft.longitude = lon;

              // 3. Add to path history
              final newPos = LatLng(lat, lon);
              if (aircraft.pathHistory.isEmpty ||
                  aircraft.pathHistory.last != newPos) {
                aircraft.pathHistory.add(newPos);
              }
              updated = true;
            }
          }
          break;
        case '4': // Airborne Velocity
          if (parts.length >= 15 &&
              parts[12].isNotEmpty &&
              parts[13].isNotEmpty) {
            aircraft.groundSpeed = int.tryParse(parts[12]);
            aircraft.track = int.tryParse(parts[13]); // Heading
            updated = true;
          }
          break;
        // Other MSG types (2, 5, 6, 7, 8) are ignored for this example
      }

      if (updated) {
        aircraft.lastUpdated = DateTime.now();

        // --- FIX 2: Replace setState with notifyListeners ---
        // Just update the data directly
        _aircraft[icao] = aircraft;
        // And then notify all listeners that the data has changed
        notifyListeners();
      }
    } catch (e) {
      print("Error parsing message: $message\nError: $e");
    }
  }

  /// Removes aircraft that haven't been updated in over 60 seconds.
  void _pruneOldAircraft() {
    final now = DateTime.now();
    int removedCount = 0;

    // --- FIX 3: Remove setState and call removeWhere directly ---
    _aircraft.removeWhere((key, aircraft) {
      final shouldRemove =
          now.difference(aircraft.lastUpdated).inSeconds > 60;
      if (shouldRemove) {
        removedCount++;
      }
      return shouldRemove;
    });

    // Only notify listeners if something was actually removed
    if (removedCount > 0) {
      print("Pruned $removedCount stale aircraft.");
      notifyListeners();
    }
  }
}