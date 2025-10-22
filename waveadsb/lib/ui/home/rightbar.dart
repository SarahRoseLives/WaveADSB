// ui/home/rightbar.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class RightSidebar extends StatelessWidget {
  // 1. Add MapController and ValueNotifier to constructor
  final MapController mapController;
  final ValueNotifier<double> zoomNotifier;

  const RightSidebar({
    required this.mapController,
    required this.zoomNotifier,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // 2. Widen the container slightly for the slider
      width: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF252526),
        border: Border(
          left: BorderSide(color: Colors.black.withOpacity(0.5), width: 1),
        ),
      ),
      // 3. Use RotatedBox to make the slider vertical
      child: RotatedBox(
        quarterTurns: -1, // Rotate 270 degrees (counter-clockwise)
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          // 4. Use ValueListenableBuilder to rebuild the slider on zoom changes
          child: ValueListenableBuilder<double>(
            valueListenable: zoomNotifier,
            builder: (context, currentZoom, child) {
              return Slider(
                value: currentZoom,
                min: 1.0,  // Min zoom for flutter_map
                max: 18.0, // Max zoom for flutter_map
                divisions: 17, // 18 - 1 = 17 steps
                activeColor: Colors.cyanAccent,
                inactiveColor: Colors.grey[700],
                // 5. onChanged updates the map zoom
                onChanged: (newZoom) {
                  // Move the map to the new zoom level, keeping it centered
                  mapController.move(mapController.camera.center, newZoom);
                  // We also update the notifier directly for instant UI feedback
                  // in case the map event is slow
                  zoomNotifier.value = newZoom;
                },
              );
            },
          ),
        ),
      ),
    );
  }
}