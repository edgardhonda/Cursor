import 'package:flutter/services.dart';

/// Esconde status bar e barra de navegação (modo imersivo).
Future<void> hideSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

/// Restaura status bar e barra de navegação.
Future<void> showSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
}

/// Botões físicos comuns no Android (voltar, volume).
bool isPhysicalSystemKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.audioVolumeUp ||
      key == LogicalKeyboardKey.audioVolumeDown ||
      key == LogicalKeyboardKey.audioVolumeMute;
}
