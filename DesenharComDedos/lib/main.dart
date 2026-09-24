import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/drawing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const DesenharComDedosApp());
}

class DesenharComDedosApp extends StatelessWidget {
  const DesenharComDedosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Desenhar com Dedos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      home: const DrawingScreen(),
    );
  }
}
