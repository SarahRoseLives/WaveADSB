// ui/configure/map.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:waveadsb/services/settings_service.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

// Constants for slider
const double _minRadiusNM = 10.0;
const double _maxRadiusNM = 200.0;
const int _sliderDivisions = 19; // (200 - 10) / 10 = 19 steps

class ConfigureMapScreen extends StatefulWidget {
  const ConfigureMapScreen({super.key});

  @override
  State<ConfigureMapScreen> createState() => _ConfigureMapScreenState();
}

class _ConfigureMapScreenState extends State<ConfigureMapScreen> {
  Future<int?>? _tileCountFuture;
  Stream<DownloadProgress>? _downloadProgressStream;
  DownloadProgress? _latestDownloadProgress;
  bool _isDownloading = false;
  double _selectedRadiusNM = 50.0; // Default radius

  @override
  void initState() {
    super.initState();
    _loadTileCount();
    // Potentially load saved radius preference here if implemented
  }

  void _loadTileCount() {
    if (!mounted) return;
    setState(() {
      _tileCountFuture = FMTCStore('default').stats.length;
    });
  }

  void _showSnackbar(BuildContext context, String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : Colors.blueGrey,
      ),
    );
  }

  Future<void> _startDownload(SettingsService settings) async {
    if (_isDownloading) {
      _showSnackbar(context, 'Download already in progress.');
      return;
    }
    if (settings.homeLocation == null) {
      _showSnackbar(context, 'Please set a home location on the map first.', error: true);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isDownloading = true;
      _latestDownloadProgress = null;
    });

    // *** Use the selected radius ***
    final double radiusInMeters = _selectedRadiusNM * 1852; // Convert NM to meters
    _showSnackbar(context, 'Starting download for ${_selectedRadiusNM.round()} NM radius...');


    try {
      const Distance distance = Distance();
      // Use radiusInMeters for calculation
      final LatLng northEast = distance.offset(
          settings.homeLocation!, radiusInMeters, 45);
      final LatLng southWest = distance.offset(
          settings.homeLocation!, radiusInMeters, 225);

      final LatLngBounds bounds = LatLngBounds(northEast, southWest);

      final downloadableRegion = RectangleRegion(bounds).toDownloadable(
        minZoom: 1,
        maxZoom: 12, // Still keeping max zoom at 12 for performance
        options: TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.waveadsb',
        ),
      );

      final streams = FMTCStore('default').download.startForeground(
        region: downloadableRegion,
      );

      _downloadProgressStream = streams.downloadProgress;

      await for (final progress in _downloadProgressStream!) {
        if (!mounted) break;
        setState(() {
          _latestDownloadProgress = progress;
        });
      }
      _showSnackbar(context, 'Offline map download finished!');

    } catch (e, s) {
      print('Download Error: $e\n$s');
      _showSnackbar(context, 'Download failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgressStream = null;
        });
      }
      _loadTileCount();
    }
  }

  Future<void> _cancelDownload() async {
    if (!_isDownloading) return;
    try {
      await FMTCStore('default').download.cancel();
      _showSnackbar(context, 'Download cancelled.');
    } catch (e, s) {
      print('Cancel Error: $e\n$s');
      _showSnackbar(context, 'Failed to cancel download: $e', error: true);
    }
    // State update is handled in _startDownload's finally block
  }


  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Settings'),
        actions: [
          if (_isDownloading)
            IconButton(
              icon: const Icon(Icons.cancel),
              tooltip: 'Cancel Download',
              onPressed: _cancelDownload,
            ),
        ],
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Show Flight Paths'),
            subtitle: const Text(
                'Draw a line on the map showing the aircraft\'s path'),
            value: settings.showFlightPaths,
            onChanged: _isDownloading ? null : (bool newValue) {
              settings.updateShowFlightPaths(newValue);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Offline Mode'),
            subtitle: const Text('Use downloaded map tiles (if available)'),
            value: settings.offlineMode,
            onChanged: _isDownloading ? null : (bool newValue) {
              settings.updateOfflineMode(newValue);
            },
          ),
          const Divider(),
          // --- Tile Count Display ---
          FutureBuilder<int?>(
            future: _tileCountFuture,
            builder: (context, snapshot) {
              String countText = 'Loading...';
              IconData icon = Icons.storage_rounded; // Changed icon slightly
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) {
                  countText = 'Error';
                  icon = Icons.error_outline;
                  print("Error loading tile count: ${snapshot.error}");
                } else {
                  countText = '${snapshot.data ?? 0} tiles';
                  icon = Icons.storage_rounded;
                }
              }
              return ListTile(
                leading: Icon(icon),
                title: const Text('Cached Tiles'),
                trailing: Text(countText),
                dense: true, // Make it a bit smaller
              );
            },
          ),
          // --- Radius Slider ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
            child: Text(
              'Download Radius: ${_selectedRadiusNM.round()} NM',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Slider(
            value: _selectedRadiusNM,
            min: _minRadiusNM,
            max: _maxRadiusNM,
            divisions: _sliderDivisions,
            label: '${_selectedRadiusNM.round()} NM',
            onChanged: _isDownloading ? null : (double value) { // Disable during download
              setState(() {
                _selectedRadiusNM = value;
                // You could save this preference using SharedPreferences if desired
              });
            },
            activeColor: Colors.cyanAccent,
            inactiveColor: Colors.grey[700],
          ),
          // --- Download Button ---
          ListTile(
            leading: const Icon(Icons.download_for_offline),
            title: const Text('Download Map Area'),
            subtitle: Text(
                'Download ${_selectedRadiusNM.round()} NM radius around home (Zooms 1-12)'), // Updated text
            trailing: IconButton(
              icon: const Icon(Icons.download),
              onPressed: _isDownloading ? null : () => _startDownload(settings),
            ),
          ),
          // --- Download Progress ---
          if (_isDownloading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Downloading: ${_latestDownloadProgress == null ? 0 : _latestDownloadProgress!.percentageProgress.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _latestDownloadProgress == null ? 0 : _latestDownloadProgress!.percentageProgress / 100,
                    backgroundColor: Colors.grey[700],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                  ),
                   const SizedBox(height: 4),
                   Text(
                     _latestDownloadProgress == null
                       ? 'Starting...'
                       : 'Attempted: ${_latestDownloadProgress!.attemptedTilesCount} / ${_latestDownloadProgress!.maxTilesCount} | TPS: ${_latestDownloadProgress!.tilesPerSecond.toStringAsFixed(1)} | Remaining: ~${_latestDownloadProgress!.estRemainingDuration.inMinutes} min',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[400]),
                   ),
                ],
              ),
            ),
          // --- Clear Cache Button ---
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red[400]),
            title: Text('Clear Tile Cache',
                style: TextStyle(color: Colors.red[400])),
            subtitle: const Text('Delete all downloaded map tiles'),
            onTap: _isDownloading ? null : () async { // Disable during download
              try {
                await FMTCStore('default').manage.reset();
                _showSnackbar(context, 'Tile cache cleared.');
                _loadTileCount();
              } catch (e, s) {
                print('Cache Clear Error: $e\n$s');
                _showSnackbar(context, 'Failed to clear cache: $e', error: true);
                _loadTileCount();
              }
            },
          ),
        ],
      ),
    );
  }
}