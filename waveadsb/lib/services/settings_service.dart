import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart'; // Import LatLng
import 'package:waveadsb/models/port_config.dart';

class SettingsService with ChangeNotifier {
  late SharedPreferences _prefs;

  // --- Port Settings ---
  final List<PortConfig> _ports = [];
  static const String _portsKey = 'port_configs';
  List<PortConfig> get ports => List.unmodifiable(_ports); // Return unmodifiable

  // --- Home Location ---
  LatLng? _homeLocation;
  static const String _homeLatKey = 'home_latitude';
  static const String _homeLonKey = 'home_longitude';
  LatLng? get homeLocation => _homeLocation;

  // --- Screen Settings (FIX) ---
  bool _showStationLines = false;
  static const String _showStationLinesKey = 'show_station_lines';
  bool get showStationLines => _showStationLines;

  // --- Map Settings (NEW) ---
  bool _showFlightPaths = true;
  static const String _showFlightPathsKey = 'show_flight_paths';
  bool get showFlightPaths => _showFlightPaths;

  // --- Initialization ---
  Future<void> loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    // Load Ports
    final List<String> portJsonList = _prefs.getStringList(_portsKey) ?? [];
    _ports.clear();
    for (String portJson in portJsonList) {
      _ports.add(PortConfig.fromJson(portJson));
    }

    // Load Home Location
    final double? lat = _prefs.getDouble(_homeLatKey);
    final double? lon = _prefs.getDouble(_homeLonKey);
    if (lat != null && lon != null) {
      _homeLocation = LatLng(lat, lon);
    } else {
      _homeLocation = null;
    }

    // Load Screen Settings
    _showStationLines = _prefs.getBool(_showStationLinesKey) ?? false;

    // Load Map Settings
    _showFlightPaths = _prefs.getBool(_showFlightPathsKey) ?? true;

    // Notify listeners that all settings are loaded
    notifyListeners();
  }

  // --- Port Methods ---
  Future<void> _savePorts() async {
    final List<String> portJsonList =
        _ports.map((port) => port.toJson()).toList();
    await _prefs.setStringList(_portsKey, portJsonList);
  }

  Future<void> addPort(PortConfig config) async {
    _ports.add(config);
    await _savePorts();
    notifyListeners();
  }

  Future<void> removePort(PortConfig config) async {
    _ports.remove(config);
    await _savePorts();
    notifyListeners();
  }

  Future<void> updatePort(int index, PortConfig newConfig) async {
    if (index >= 0 && index < _ports.length) {
      _ports[index] = newConfig;
      await _savePorts();
      notifyListeners();
    }
  }

  // --- Home Location Method ---
  Future<void> updateHomeLocation(LatLng? newLocation) async {
    _homeLocation = newLocation;
    if (newLocation != null) {
      await _prefs.setDouble(_homeLatKey, newLocation.latitude);
      await _prefs.setDouble(_homeLonKey, newLocation.longitude);
    } else {
      await _prefs.remove(_homeLatKey);
      await _prefs.remove(_homeLonKey);
    }
    notifyListeners();
  }

  // --- Screen Settings Method (FIX) ---
  Future<void> updateShowStationLines(bool newValue) async {
    _showStationLines = newValue;
    await _prefs.setBool(_showStationLinesKey, newValue);
    notifyListeners();
  }

  // --- Map Settings Method (NEW) ---
  Future<void> updateShowFlightPaths(bool newValue) async {
    _showFlightPaths = newValue;
    await _prefs.setBool(_showFlightPathsKey, newValue);
    notifyListeners();
  }
}