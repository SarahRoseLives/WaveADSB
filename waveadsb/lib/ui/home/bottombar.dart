// ui/home/bottombar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waveadsb/services/adsb_service.dart';

class BottomBar extends StatelessWidget {
  const BottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch the AdsbService for status changes
    final status = context.watch<AdsbService>().status;

    // Determine color based on status
    Color statusBarColor;
    if (status.startsWith('Connected')) {
      statusBarColor = const Color(0xFF007ACC); // Blue for connected
    } else if (status.startsWith('Connecting') || status.startsWith('Failed')) {
      statusBarColor = Colors.orange[700]!; // Orange for retrying/connecting
    } else {
      statusBarColor = Colors.grey[700]!; // Grey for idle/no ports
    }

    return Container(
      height: 30,
      color: statusBarColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Status: $status',
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          // You could add other info here, like total aircraft count
          Text(
            'WaveADSB',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}