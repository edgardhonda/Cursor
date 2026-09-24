import 'dart:io';

import 'package:image/image.dart';

/// Gera assets/app_icon.png — pequeno carro estilo doodle.
void main() {
  const size = 1024;
  final image = Image(width: size, height: size);
  fill(image, color: ColorRgb8(255, 255, 255));

  final black = ColorRgb8(0, 0, 0);

  // corpo (fusca doodle)
  drawLine(image, x1: 280, y1: 620, x2: 340, y2: 480, color: black, thickness: 16);
  drawLine(image, x1: 340, y1: 480, x2: 520, y2: 440, color: black, thickness: 16);
  drawLine(image, x1: 520, y1: 440, x2: 720, y2: 480, color: black, thickness: 16);
  drawLine(image, x1: 720, y1: 480, x2: 760, y2: 620, color: black, thickness: 16);
  drawLine(image, x1: 760, y1: 620, x2: 280, y2: 620, color: black, thickness: 16);

  // janela
  drawLine(image, x1: 420, y1: 500, x2: 620, y2: 480, color: black, thickness: 12);
  drawLine(image, x1: 420, y1: 500, x2: 400, y2: 560, color: black, thickness: 12);
  drawLine(image, x1: 620, y1: 480, x2: 640, y2: 560, color: black, thickness: 12);

  // rodas
  fillCircle(image, x: 380, y: 640, radius: 52, color: black);
  fillCircle(image, x: 380, y: 640, radius: 20, color: ColorRgb8(255, 255, 255));
  fillCircle(image, x: 660, y: 640, radius: 52, color: black);
  fillCircle(image, x: 660, y: 640, radius: 20, color: ColorRgb8(255, 255, 255));

  // farol
  fillCircle(image, x: 748, y: 560, radius: 14, color: ColorRgb8(255, 235, 59));

  final out = File('assets/app_icon.png');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(encodePng(image));
  stdout.writeln('Icon saved to ${out.path}');
}
