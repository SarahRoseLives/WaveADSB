// models/station_data.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// Enum to represent different station types for icon selection
enum StationType {
  car,
  wx,
  base,
  freq,
  aircraft, // NEW
  boat,     // NEW
  repeater, // NEW
  digi,     // NEW
  unknown
}

// A simple class to hold station data
class StationData {
  final String callsign;
  final String? details;
  final StationType type;
  final Color color;
  final LatLng? mapPosition;
  final DateTime lastHeard;
  final String? rawPacket;
  final List<String>? path;

  StationData({
    required this.callsign,
    this.details,
    this.type = StationType.unknown,
    this.color = Colors.white,
    this.mapPosition,
    required this.lastHeard,
    this.rawPacket,
    this.path,
  });
}

// We still keep homeBase for centering the map
final LatLng homeBase =
    const LatLng(41.4993, -81.6944); // Cleveland as a center point