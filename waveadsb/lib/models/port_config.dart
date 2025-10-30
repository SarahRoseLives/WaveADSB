// models/port_config.dart
import 'dart:convert';

// 1. RENAME ENUM
enum PortType {
  sbsFeed_TCP,
  acarsdec_JSON_UDP_Listen, // Changed from TCP to UDP
}

// 2. Helper extension for user-friendly names (optional but nice)
extension PortTypeExtension on PortType {
  String get friendlyName {
    switch (this) {
      case PortType.sbsFeed_TCP:
        return 'ADS-B (SBS-1 TCP Client)';
      // 3. UPDATE TEXT
      case PortType.acarsdec_JSON_UDP_Listen:
        return 'ACARS (acarsdec JSON UDP Listener)';
    }
  }
}

class PortConfig {
  final String name;
  final PortType type;
  final String host;
  final int port;

  PortConfig({
    required this.name,
    required this.type,
    required this.host,
    required this.port,
  });

  // --- Serialization ---

  // Convert a PortConfig object into a Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name, // Saves the enum as a string
      'host': host,
      'port': port,
    };
  }

  // Create a PortConfig object from a Map
  factory PortConfig.fromMap(Map<String, dynamic> map) {
    return PortConfig(
      name: map['name'] ?? 'Untitled Feed',
      // Convert string back to enum
      type: PortType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PortType.sbsFeed_TCP, // 4. Keep default
      ),
      host: map['host'] ?? '127.0.0.1',
      port: map['port'] ?? 30003,
    );
  }

  // Convert a PortConfig object into a JSON string
  String toJson() => json.encode(toMap());

  // Create a PortConfig object from a JSON string
  factory PortConfig.fromJson(String source) =>
      PortConfig.fromMap(json.decode(source));
}