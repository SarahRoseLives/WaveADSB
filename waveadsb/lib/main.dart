// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:waveadsb/services/adsb_service.dart'; // Import NEW service
import 'package:waveadsb/services/settings_service.dart';
import 'package:waveadsb/ui/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.loadSettings();

  runApp(
    MultiProvider(
      providers: [
        // The SettingsService provider
        ChangeNotifierProvider(
          create: (context) => settingsService,
        ),

        // The new AdsbService provider
        // It's a "Proxy" because it depends on the SettingsService
        ChangeNotifierProxyProvider<SettingsService, AdsbService>(
          // It creates the AdsbService, passing the SettingsService to it
          create: (context) => AdsbService(settingsService),

          // This handles if settings are updated
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