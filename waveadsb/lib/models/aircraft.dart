// models/aircraft.dart
import 'package:latlong2/latlong.dart';

/// Represents a single aircraft being tracked.
class Aircraft {
  final String icao; // Unique 6-digit hex code
  String? callsign;
  double? latitude;
  double? longitude;
  int? altitude;
  int? groundSpeed;
  int? track; // Heading in degrees
  DateTime lastUpdated;

  Aircraft(this.icao) : lastUpdated = DateTime.now();

  /// Helper to check if the aircraft has a valid position to be plotted.
  bool get hasPosition => latitude != null && longitude != null;

  /// Creates a LatLng object, or null if no position.
  LatLng? get position =>
      hasPosition ? LatLng(latitude!, longitude!) : null;
}