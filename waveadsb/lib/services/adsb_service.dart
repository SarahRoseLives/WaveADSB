// services/adsb_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
// Removed unused dart:typed_data import
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart';
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
  // *** CONFIRMED: Using a Map ***
  final Map<String, Socket> _activeSockets = {};
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
    print('ADSB Service: Disposing...');
    _pruneTimer?.cancel();
    // Set desired connection to false for all ports on dispose
    final portIds = _portConnectionDesired.keys.toList();
    for (final portId in portIds) {
       _portConnectionDesired[portId] = false;
    }
    // Destroy all active sockets on dispose - iterate safely
    final socketsToDestroy = _activeSockets.values.toList(); // Create copy
    for (final socket in socketsToDestroy) {
      // Use destroy() which closes and cleans up resources immediately
      socket.destroy();
    }
    _activeSockets.clear(); // Clear the map
    super.dispose();
  }

  // Helper to update status and notify listeners
  void _updateStatus(String? add, {String? remove}) {
    // print('Updating status: Add="$add", Remove="$remove"'); // Debugging
    if (remove != null) {
      _statusMessages.removeWhere((m) => m.startsWith(remove));
    }
    if (add != null) {
       // Avoid duplicate status messages
      if (!_statusMessages.contains(add)) {
          _statusMessages.insert(0, add);
      }
    }
    // print('Current status: $status'); // Debugging
    notifyListeners();
  }

  /// Public method to be called when settings change
  void updateSettings(SettingsService newSettings) {
    final oldPortsJson = _settingsService.ports.map((p) => p.toJson()).toList();
    final newPortsJson = newSettings.ports.map((p) => p.toJson()).toList();

    if (!const DeepCollectionEquality().equals(oldPortsJson, newPortsJson)) {
        print('ADSB Service: Port settings changed, reconnecting feeds.');
        _settingsService = newSettings;
        connectToFeeds();
    } else {
        _settingsService = newSettings;
    }
  }


  // Main connection trigger/reset
  void connectToFeeds() {
    print('ADSB Service: Re-evaluating connections...');

    final currentPorts = _settingsService.ports;
    final Set<String> currentPortIds = currentPorts.map((p) => p.name).toSet();
    final Set<String> desiredPortIds = _portConnectionDesired.keys.toSet();

    // Ports to disconnect (were desired, but are not in current settings)
    final portsToDisconnect = desiredPortIds.difference(currentPortIds);
    for (final portId in portsToDisconnect) {
        print('ADSB Service: Marking port "$portId" for disconnection.');
        _portConnectionDesired[portId] = false;
        _activeSockets[portId]?.destroy();
        _activeSockets.remove(portId);
    }

    // Ports to connect (in current settings, might be new or existing)
    if (currentPorts.isEmpty) {
        _statusMessages.clear();
        _statusMessages.add('No feeds configured.');
        notifyListeners();
        print('ADSB Service: No feeds configured.');
        return;
    }

    _statusMessages.clear();
    for (final port in currentPorts) {
        final portId = port.name;
        if (_portConnectionDesired[portId] != true) {
            print('ADSB Service: Marking port "$portId" for connection.');
            _portConnectionDesired[portId] = true;
            _managePortConnection(port);
        } else {
             print('ADSB Service: Port "$portId" connection already managed.');
              final existingSocket = _activeSockets[portId];
              if (existingSocket != null) {
                 _updateStatus('Connected: ${port.name}');
              } else {
                 // Try to find a relevant existing status message (more robust needed if complex states exist)
                 final existingStatus = _statusMessages.firstWhere(
                    (s) => s.contains(port.name), orElse: () => 'Connecting to ${port.name}...',
                 );
                 _updateStatus(existingStatus);
              }
        }
    }
     if (_statusMessages.isEmpty) {
       _statusMessages.add('Initializing connections...');
     }
     notifyListeners();
  }

  // Persistent connection loop for one port
  Future<void> _managePortConnection(PortConfig port) async {
    final portId = port.name;
    print('Starting connection manager for ${port.name}');

    while (_portConnectionDesired[portId] == true) {
      Socket? socket;
      StreamSubscription? subscription;
      final completer = Completer<void>();

      try {
        _updateStatus('Connecting to ${port.name}...', remove: 'Failed to connect: ${port.name}');
        _updateStatus(null, remove: 'Disconnected: ${port.name}');
        _updateStatus(null, remove: 'Stopped: ${port.name}');

        socket = await Socket.connect(
            port.host,
            port.port,
            timeout: const Duration(seconds: 5),
        );
        print('Socket connected for ${port.name}');
        _activeSockets[portId] = socket; // Use Map correctly
        _updateStatus('Connected: ${port.name}', remove: 'Connecting to ${port.name}');

        subscription = utf8.decoder
            .bind(socket)
            .transform(const LineSplitter())
            .listen(
          (String line) {
            _parseSbsMessage(line);
          },
          onDone: () {
            print('Socket done for ${port.name}');
            _updateStatus('Disconnected: ${port.name}', remove: 'Connected: ${port.name}');
            if (!completer.isCompleted) completer.complete();
          },
          onError: (e, stackTrace) {
            print('Socket error for ${port.name}: $e\n$stackTrace');
            _updateStatus('Socket Error (${port.name}): $e', remove: 'Connected: ${port.name}');
            if (!completer.isCompleted) completer.completeError(e, stackTrace);
          },
          cancelOnError: true,
        );

        await completer.future;

      } catch (e, stackTrace) {
        print('Connection failed for ${port.name}: $e\n$stackTrace');
         _updateStatus('Failed to connect: ${port.name}. Retrying in 10s...', remove: 'Connecting to ${port.name}');
         if (!completer.isCompleted) completer.completeError(e, stackTrace);
      } finally {
        print('Cleaning up connection for ${port.name}');
        await subscription?.cancel();
        if (_activeSockets[portId] == socket) {
             _activeSockets.remove(portId); // Use Map correctly
        }
        socket?.destroy();

         _updateStatus(null, remove: 'Connected: ${port.name}');
      }

      if (_portConnectionDesired[portId] == true) {
        print('Retrying connection for ${port.name} in 10 seconds...');
        await Future.delayed(const Duration(seconds: 10));
      }
    } // End while loop

    print('Stopping connection manager for ${port.name} as it is no longer desired.');
     _updateStatus('Stopped: ${port.name}', remove: 'Connecting to ${port.name}');
     _updateStatus(null, remove: 'Failed to connect: ${port.name}');
     _updateStatus(null, remove: 'Disconnected: ${port.name}');
     _updateStatus(null, remove: 'Connected: ${port.name}');
     _updateStatus(null, remove: 'Socket Error (${port.name})');
     if (_portConnectionDesired.values.where((v) => v == true).isEmpty && _activeSockets.isEmpty) {
        if(!_statusMessages.contains('Not connected')) {
           _statusMessages.clear();
           _statusMessages.add('Not connected');
        }
     }
     notifyListeners();
  }


  /// Parses a single SBS-1 (BaseStation) message line.
  void _parseSbsMessage(String message) {
    if (message.isEmpty) return;

    final parts = message.split(',');
    if (parts.length < 11 || parts[0] != 'MSG') {
      return;
    }

    final messageType = parts[1];
    final icao = parts[4].toUpperCase();
     if (icao.isEmpty || icao.length != 6 || !RegExp(r'^[A-F0-9]+$').hasMatch(icao)) {
        return;
     }

    final aircraft = _aircraft.putIfAbsent(icao, () => Aircraft(icao));
    bool updated = false;

    try {
      switch (messageType) {
        case '1': // Callsign
          if (parts.length >= 11) {
            final callsign = parts[10].trim();
            if (callsign.isNotEmpty && aircraft.callsign != callsign) {
              aircraft.callsign = callsign;
              updated = true;
            }
          }
          break;
        case '3': // Airborne Position
          if (parts.length >= 16 &&
              parts[14].isNotEmpty &&
              parts[15].isNotEmpty) {
            final altStr = parts.length > 11 ? parts[11] : '';
            final latStr = parts[14];
            final lonStr = parts[15];

            final lat = double.tryParse(latStr);
            final lon = double.tryParse(lonStr);
            final alt = int.tryParse(altStr);

            if (lat != null && lon != null && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
              // Only update if position actually changed significantly (optional)
              {
                aircraft.altitude = alt;
                aircraft.latitude = lat;
                aircraft.longitude = lon;

                final newPos = LatLng(lat, lon);
                 if (aircraft.pathHistory.isEmpty || aircraft.pathHistory.last != newPos) {
                   aircraft.pathHistory.add(newPos);
                 }
                updated = true;
              }
            }
          }
          break;
        case '4': // Airborne Velocity
          if (parts.length >= 14 &&
              parts[12].isNotEmpty &&
              parts[13].isNotEmpty) {
            final gsStr = parts[12];
            final trackStr = parts[13];

            final gs = int.tryParse(gsStr);
            final track = int.tryParse(trackStr);

            if (gs != null && track != null && gs >= 0 && track >= 0 && track < 360) {
               if (aircraft.groundSpeed != gs || aircraft.track != track) {
                  aircraft.groundSpeed = gs;
                  aircraft.track = track;
                  updated = true;
               }
            }
          }
          break;
      }

      if (updated) {
        aircraft.lastUpdated = DateTime.now();
        _aircraft[icao] = aircraft;
        notifyListeners();
      }
    } catch (e, stackTrace) {
       print("Error parsing message: $message\nError: $e\n$stackTrace");
    }
  }


  /// Removes aircraft that haven't been updated in over 60 seconds.
  void _pruneOldAircraft() {
    final now = DateTime.now();
    int removedCount = 0;
    final keysToRemove = <String>[];

    _aircraft.forEach((key, aircraft) {
      if (now.difference(aircraft.lastUpdated).inSeconds > 60) {
        keysToRemove.add(key);
      }
    });

    if (keysToRemove.isNotEmpty) {
       for (final key in keysToRemove) {
         _aircraft.remove(key);
         removedCount++;
       }
       print("Pruned $removedCount stale aircraft.");
       notifyListeners();
    }
  }
}