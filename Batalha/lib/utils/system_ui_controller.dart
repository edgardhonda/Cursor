import 'package:flutter/services.dart';

Future<void> enterImmersiveMode() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

Future<void> hideSystemUi() => enterImmersiveMode();

Future<void> showSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
}
