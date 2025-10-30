// services/adsb_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Ensure this is imported
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart';
import 'package:waveadsb/models/aircraft.dart';
import 'package:waveadsb/models/port_config.dart';
import 'package:waveadsb/services/settings_service.dart';
import 'package:waveadsb/models/message.dart';

class AdsbService with ChangeNotifier {
  SettingsService _settingsService;

  // --- Aircraft Data ---
  final Map<String, Aircraft> _aircraft = {};
  List<Aircraft> get aircraft =>
      _aircraft.values.sorted((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

  // --- ACARS Data (NEW) ---
  final List<Message> _acarsMessages = [];
  List<Message> get acarsMessages => List.unmodifiable(_acarsMessages);

  // --- Connection Status & Management ---
  final List<String> _statusMessages = ['Not connected'];
  String get status => _statusMessages.firstOrNull ?? 'Idle';

  // *** UPDATED SOCKET MAPS ***
  final Map<String, Socket> _activeSbsSockets = {};
  // We rename the server socket map to be generic for TCP servers
  final Map<String, ServerSocket> _activeTcpServerSockets = {};
  // We track client sockets for TCP servers
  final Map<ServerSocket, List<Socket>> _serverClientSockets = {};
  // *** NEW MAP FOR UDP SOCKETS ***
  final Map<String, RawDatagramSocket> _activeUdpSockets = {};

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
    final portIds = _portConnectionDesired.keys.toList();
    for (final portId in portIds) {
      _portConnectionDesired[portId] = false;
    }

    // *** UPDATED DISPOSE LOGIC ***
    // Destroy all active SBS client sockets
    final sbsSocketsToDestroy = _activeSbsSockets.values.toList();
    for (final socket in sbsSocketsToDestroy) {
      socket.destroy();
    }
    _activeSbsSockets.clear();

    // Close all active TCP server sockets and their clients
    final tcpServerSocketsToClose = _activeTcpServerSockets.values.toList();
    for (final serverSocket in tcpServerSocketsToClose) {
      _serverClientSockets[serverSocket]?.forEach((client) => client.destroy());
      serverSocket.close();
    }
    _activeTcpServerSockets.clear();
    _serverClientSockets.clear();

    // Close all active UDP sockets
    final udpSocketsToClose = _activeUdpSockets.values.toList();
    for (final udpSocket in udpSocketsToClose) {
      udpSocket.close();
    }
    _activeUdpSockets.clear();

    super.dispose();
  }

  // Helper to update status and notify listeners
  void _updateStatus(String? add, {String? remove}) {
    if (remove != null) {
      _statusMessages.removeWhere((m) => m.startsWith(remove));
    }
    if (add != null) {
      if (!_statusMessages.contains(add)) {
        _statusMessages.insert(0, add);
      }
    }
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

      // *** UPDATED DISCONNECT LOGIC ***
      _activeSbsSockets[portId]?.destroy();
      _activeSbsSockets.remove(portId);
      _activeTcpServerSockets[portId]?.close();
      _activeTcpServerSockets.remove(portId);
      _activeUdpSockets[portId]?.close(); // Close UDP socket
      _activeUdpSockets.remove(portId);
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
        _managePortConnection(port); // ROUTER
      } else {
        print('ADSB Service: Port "$portId" connection already managed.');
        // *** UPDATED STATUS CHECK ***
        final existingSbsSocket = _activeSbsSockets[portId];
        final existingTcpServerSocket = _activeTcpServerSockets[portId];
        final existingUdpSocket = _activeUdpSockets[portId];

        if (existingSbsSocket != null) {
          _updateStatus('Connected SBS: ${port.name}');
        } else if (existingTcpServerSocket != null) {
          _updateStatus('Listening (TCP): ${port.name}'); // Generic TCP
        } else if (existingUdpSocket != null) {
           _updateStatus('Listening for ACARS: ${port.name}'); // UDP
        } else {
          final existingStatus = _statusMessages.firstWhere(
            (s) => s.contains(port.name),
            orElse: () => 'Connecting to ${port.name}...',
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

  // ROUTER METHOD
  Future<void> _managePortConnection(PortConfig port) async {
    switch (port.type) {
      case PortType.sbsFeed_TCP:
        await _manageSbsClientConnection(port);
        break;
      case PortType.acarsdec_JSON_UDP_Listen: // *** USE NEW ENUM ***
        await _manageAcarsUdpListenerConnection(port); // *** CALL NEW FUNCTION ***
        break;
    }
  }

  // Persistent connection loop for one port (SBS-1 TCP CLIENT)
  Future<void> _manageSbsClientConnection(PortConfig port) async {
    final portId = port.name;
    print('Starting SBS-1 client manager for ${port.name}');

    while (_portConnectionDesired[portId] == true) {
      Socket? socket;
      StreamSubscription? subscription;
      final completer = Completer<void>();

      try {
        _updateStatus('Connecting to SBS: ${port.name}...',
            remove: 'Failed to connect: ${port.name}');
        _updateStatus(null, remove: 'Disconnected: ${port.name}');
        _updateStatus(null, remove: 'Stopped: ${port.name}');

        socket = await Socket.connect(
          port.host,
          port.port,
          timeout: const Duration(seconds: 5),
        );
        print('SBS Socket connected for ${port.name}');
        _activeSbsSockets[portId] = socket;
        _updateStatus('Connected SBS: ${port.name}',
            remove: 'Connecting to SBS: ${port.name}');

        subscription = utf8.decoder
            .bind(socket)
            .transform(const LineSplitter())
            .listen(
          (String line) {
            _parseSbsMessage(line);
          },
          onDone: () {
            print('SBS Socket done for ${port.name}');
            _updateStatus('Disconnected: ${port.name}',
                remove: 'Connected SBS: ${port.name}');
            if (!completer.isCompleted) completer.complete();
          },
          onError: (e, stackTrace) {
            print('SBS Socket error for ${port.name}: $e\n$stackTrace');
            _updateStatus('SBS Socket Error (${port.name}): $e',
                remove: 'Connected SBS: ${port.name}');
            if (!completer.isCompleted) completer.completeError(e, stackTrace);
          },
          cancelOnError: true,
        );

        await completer.future;
      } catch (e, stackTrace) {
        print('SBS Connection failed for ${port.name}: $e\n$stackTrace');
        _updateStatus('Failed to connect: ${port.name}. Retrying in 10s...',
            remove: 'Connecting to SBS: ${port.name}');
        if (!completer.isCompleted) completer.completeError(e, stackTrace);
      } finally {
        print('Cleaning up SBS connection for ${port.name}');
        await subscription?.cancel();
        if (_activeSbsSockets[portId] == socket) {
          _activeSbsSockets.remove(portId);
        }
        socket?.destroy();
        _updateStatus(null, remove: 'Connected SBS: ${port.name}');
      }

      if (_portConnectionDesired[portId] == true) {
        print('Retrying SBS connection for ${port.name} in 10 seconds...');
        await Future.delayed(const Duration(seconds: 10));
      }
    } // End while loop

    print(
        'Stopping SBS connection manager for ${port.name} as it is no longer desired.');
    _updateStatus('Stopped: ${port.name}',
        remove: 'Connecting to SBS: ${port.name}');
    _updateStatus(null, remove: 'Failed to connect: ${port.name}');
    _updateStatus(null, remove: 'Disconnected: ${port.name}');
    _updateStatus(null, remove: 'Connected SBS: ${port.name}');
    _updateStatus(null, remove: 'SBS Socket Error (${port.name})');
    _checkIdleStatus();
  }

  // *** THIS IS THE NEW UDP LISTENER FUNCTION ***
  Future<void> _manageAcarsUdpListenerConnection(PortConfig port) async {
    final portId = port.name;
    print('Starting ACARS UDP listener manager for ${port.name}');

    RawDatagramSocket? udpSocket;

    while (_portConnectionDesired[portId] == true) {
      try {
        _updateStatus('Binding ACARS UDP listener: ${port.name} on ${port.port}...',
            remove: 'Bind failed: ${port.name}');
        _updateStatus(null, remove: 'Stopped: ${port.name}');

        // Bind a UDP socket
        udpSocket = await RawDatagramSocket.bind(port.host, port.port);
        _activeUdpSockets[portId] = udpSocket; // Store in new map
        print('ACARS UDP Server listening on ${port.host}:${port.port}');
        _updateStatus('Listening for ACARS: ${port.name}',
            remove: 'Binding ACARS UDP listener: ${port.name} on ${port.port}');

        // Listen for data
        await for (final RawSocketEvent event in udpSocket) {
          if (event == RawSocketEvent.read) {
            final Datagram? datagram = udpSocket.receive();
            if (datagram == null) continue;

            // Decode the UDP packet data to a string
            final String message = utf8.decode(datagram.data);

            // Process each line (acarsdec might send multiple JSONs in one packet)
            message.split('\n').forEach((line) {
              if (line.isNotEmpty) {
                _parseAcarsdecJsonMessage(line, port.name);
              }
            });
          }
        }
        // If the loop exits, the socket was closed
        print('ACARS UDP listener ${port.name} was closed.');

      } catch (e, stackTrace) {
        if (e is SocketException &&
            (_portConnectionDesired[portId] == false ||
             e.osError?.errorCode == 10004)) { // 10004 = socket closed
          print('ACARS UDP listener ${port.name} closed by request.');
        } else {
          print(
              'ACARS UDP listener bind failed for ${port.name}: $e\n$stackTrace');
          _updateStatus(
              'Bind failed: ${port.name}. Retrying in 10s...',
              remove: 'Binding ACARS UDP listener: ${port.name} on ${port.port}');
        }
      } finally {
        print('Cleaning up ACARS UDP listener for ${port.name}');
        if (_activeUdpSockets[portId] == udpSocket) {
           _activeUdpSockets.remove(portId);
        }
        udpSocket?.close();
        _updateStatus(null, remove: 'Listening for ACARS: ${port.name}');
      }

      if (_portConnectionDesired[portId] == true) {
        print('Retrying ACARS UDP listener for ${port.name} in 10 seconds...');
        await Future.delayed(const Duration(seconds: 10));
      }
    } // End while loop

    print(
        'Stopping ACARS UDP listener manager for ${port.name} as it is no longer desired.');
    _updateStatus('Stopped: ${port.name}',
        remove: 'Binding ACARS UDP listener: ${port.name} on ${port.port}');
    _updateStatus(null, remove: 'Bind failed: ${port.name}');
    _updateStatus(null, remove: 'Listening for ACARS: ${port.name}');
    _checkIdleStatus();
  }


  /// Checks if all connections are gone and sets status to 'Not connected'
  void _checkIdleStatus() {
    if (_portConnectionDesired.values.where((v) => v == true).isEmpty &&
        _activeSbsSockets.isEmpty &&
        _activeTcpServerSockets.isEmpty && // Check TCP
        _activeUdpSockets.isEmpty) {     // Check UDP
      if (!_statusMessages.contains('Not connected')) {
        _statusMessages.clear();
        _statusMessages.add('Not connected');
      }
      notifyListeners();
    }
  }

  // NEW JSON PARSER
  /// Parses a single acarsdec JSON message line.
  void _parseAcarsdecJsonMessage(String message, String portName) {
    if (message.isEmpty) return;

    try {
      final data = jsonDecode(message) as Map<String, dynamic>;

      // Extract timestamp
      final double ts = data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch / 1000.0;
      final timestamp =
          DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());

      final msg = Message(
        callsign: data['flight'] ?? (data['reg'] ?? 'UNKNOWN'),
        text: data['text'] ?? (data['msg_text'] ?? ''), // Added 'text' as fallback
        timestamp: timestamp,
        isIncoming: true,
      );

      _acarsMessages.add(msg);
      // Limit list size to avoid memory issues
      if (_acarsMessages.length > 200) {
        _acarsMessages.removeAt(0);
      }
      notifyListeners(); // Notify listeners that new ACARS data is available
    } catch (e, stackTrace) {
      print("Error parsing ACARS JSON: $message\nError: $e\n$stackTrace");
    }
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
    if (icao.isEmpty ||
        icao.length != 6 ||
        !RegExp(r'^[A-F0-9]+$').hasMatch(icao)) {
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

            if (lat != null &&
                lon != null &&
                lat >= -90 &&
                lat <= 90 &&
                lon >= -180 &&
                lon <= 180) {
              // Only update if position actually changed significantly (optional)
              {
                aircraft.altitude = alt;
                aircraft.latitude = lat;
                aircraft.longitude = lon;

                final newPos = LatLng(lat, lon);
                if (aircraft.pathHistory.isEmpty ||
                    aircraft.pathHistory.last != newPos) {
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

            if (gs != null &&
                track != null &&
                gs >= 0 &&
                track >= 0 &&
                track < 360) {
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