// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waveadsb/services/adsb_service.dart';
import 'package:waveadsb/services/settings_service.dart';
import 'package:waveadsb/ui/home/home_screen.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart'; // 1. IMPORT

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. INITIALIZE THE TILE CACHE DATABASE
  try {
    await FMTCObjectBoxBackend().initialise();

    // *** ADD: Ensure the 'default' store exists ***
    const String defaultStoreName = 'default';
    final store = FMTCStore(defaultStoreName);
    if (!(await store.manage.ready)) {
       print('Creating cache store: $defaultStoreName');
       await store.manage.create(); // Create it if it doesn't exist
    } else {
       print('Cache store "$defaultStoreName" already exists.');
    }
    // *******************************************

  } catch (e, s) { // Catch stack trace
    print("Failed to initialize/create tile cache: $e\n$s"); // Log stack trace
    // Optionally show an error to the user or handle differently
  }

  final settingsService = SettingsService();
  await settingsService.loadSettings();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => settingsService,
        ),
        ChangeNotifierProxyProvider<SettingsService, AdsbService>(
          create: (context) => AdsbService(settingsService),
          update: (context, settings, previousAdsb) =>
              previousAdsb!..updateSettings(settings),
        ),
      ],
      child: const WaveAdsbApp(),
    ),
  );
}

class WaveAdsbApp extends StatelessWidget {
  const WaveAdsbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaveADSB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D2D2D),
        ),
        cardColor: const Color(0xFF2D2D2D),
        listTileTheme: const ListTileThemeData(
          iconColor: Colors.cyanAccent,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}