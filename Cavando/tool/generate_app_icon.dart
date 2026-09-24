import 'dart:io';

import 'package:image/image.dart';

/// Gera assets/app_icon.png — vulcão e furão do Cavando.
void main() {
  const size = 1024;
  final image = Image(width: size, height: size);

  for (var y = 0; y < size; y++) {
    final t = y / (size - 1);
    final r = (185 + t * -40).round().clamp(0, 255);
    final g = (228 + t * -30).round().clamp(0, 255);
    final b = (245 + t * -20).round().clamp(0, 255);
    final row = ColorRgb8(r, g, b);
    for (var x = 0; x < size; x++) {
      image.setPixel(x, y, row);
    }
  }

  const cx = size ~/ 2;
  fillPolygon(
    image,
    vertices: [
      Point(cx, 160),
      Point(70, 860),
      Point(size - 70, 860),
    ],
    color: ColorRgb8(160, 90, 50),
  );
  fillPolygon(
    image,
    vertices: [
      Point(cx, 160),
      Point(cx, 860),
      Point(size - 70, 860),
    ],
    color: ColorRgb8(110, 58, 28),
  );
  fillPolygon(
    image,
    vertices: [
      Point(cx - 130, 250),
      Point(cx, 155),
      Point(cx + 130, 250),
      Point(cx + 90, 360),
      Point(cx + 40, 300),
      Point(cx, 380),
      Point(cx - 50, 305),
      Point(cx - 95, 355),
    ],
    color: ColorRgb8(244, 247, 250),
  );
  fillCircle(image, x: cx, y: 195, radius: 38, color: ColorRgb8(74, 42, 24));

  // Ferret body
  fillCircle(image, x: cx - 40, y: 720, radius: 70, color: ColorRgb8(141, 90, 50));
  fillCircle(image, x: cx + 50, y: 700, radius: 58, color: ColorRgb8(141, 90, 50));
  fillCircle(image, x: cx + 20, y: 735, radius: 48, color: ColorRgb8(232, 213, 176));
  fillCircle(image, x: cx + 58, y: 688, radius: 22, color: ColorRgb8(61, 42, 28));
  fillCircle(image, x: cx + 52, y: 686, radius: 8, color: ColorRgb8(20, 16, 12));
  fillCircle(image, x: cx + 80, y: 705, radius: 10, color: ColorRgb8(232, 160, 144));

  // Tail
  for (var i = 0; i < 8; i++) {
    fillCircle(
      image,
      x: cx - 90 - i * 18,
      y: 740 + (i * i),
      radius: 28 - i * 2,
      color: ColorRgb8(141, 90, 50),
    );
  }

  Directory('assets').createSync(recursive: true);
  File('assets/app_icon.png').writeAsBytesSync(encodePng(image));
  stdout.writeln('Wrote assets/app_icon.png');
}
