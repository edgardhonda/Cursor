import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const DestruirApp());
}

class DestruirApp extends StatelessWidget {
  const DestruirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Destruir!',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC62828)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const GameScreen(),
    );
  }
}
