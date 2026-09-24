import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const DefenderCasteloApp());
}

class DefenderCasteloApp extends StatelessWidget {
  const DefenderCasteloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Defender Castelo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const GameScreen(),
    );
  }
}
