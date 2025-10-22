import 'package:flutter/material.dart';

class RightSidebar extends StatelessWidget {
  const RightSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF252526),
        border: Border(
          left: BorderSide(color: Colors.black.withOpacity(0.5), width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('MSG', style: TextStyle(fontSize: 10, color: Colors.grey)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              // RotatedBox to make the progress bar vertical
              child: RotatedBox(
                quarterTurns: -1,
                child: LinearProgressIndicator(
                  value: 0.7, // Simulated value
                  backgroundColor: Colors.grey[700],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
            ),
          ),
          const Text('DSBL', style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}