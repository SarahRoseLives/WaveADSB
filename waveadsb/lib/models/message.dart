// models/message.dart
class Message {
  final String callsign; // The *other* party's callsign
  final String text;
  final DateTime timestamp;
  final bool isIncoming; // True if received, false if sent by us

  Message({
    required this.callsign,
    required this.text,
    required this.timestamp,
    required this.isIncoming,
  });
}