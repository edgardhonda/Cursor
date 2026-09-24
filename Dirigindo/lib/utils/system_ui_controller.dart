import 'package:flutter/services.dart';

Future<void> hideSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

Future<void> showSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
}

bool isPhysicalSystemKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.audioVolumeUp ||
      key == LogicalKeyboardKey.audioVolumeDown ||
      key == LogicalKeyboardKey.audioVolumeMute;
}
