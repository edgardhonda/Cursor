import 'dart:io';
import 'dart:math';

import 'package:image/image.dart';

/// Gera assets/app_icon.png — nave do Batalha Espacial.
void main() {
  const size = 1024;
  final image = Image(width: size, height: size);
  final rng = Random(7);

  for (var y = 0; y < size; y++) {
    final t = y / (size - 1);
    final r = (2 + t * 11).round().clamp(0, 255);
    final g = (8 + t * 45).round().clamp(0, 255);
    final b = (24 + t * 98).round().clamp(0, 255);
    final row = ColorRgb8(r, g, b);
    for (var x = 0; x < size; x++) {
      image.setPixel(x, y, row);
    }
  }

  for (var i = 0; i < 90; i++) {
    final x = rng.nextInt(size);
    final y = rng.nextInt((size * 0.72).round());
    final alpha = 140 + rng.nextInt(115);
    fillCircle(
      image,
      x: x,
      y: y,
      radius: 1 + rng.nextInt(3),
      color: ColorRgba8(255, 255, 255, alpha),
    );
  }

  const cx = size ~/ 2;
  const horizonY = 620;
  final ground = ColorRgb8(20, 90, 50);
  for (var y = horizonY; y < size; y++) {
    final t = (y - horizonY) / (size - horizonY);
    final shade = (0.7 + t * 0.3).clamp(0.0, 1.0);
    final color = ColorRgb8(
      (ground.r * shade).round(),
      (ground.g * shade).round(),
      (ground.b * shade).round(),
    );
    for (var x = 0; x < size; x++) {
      image.setPixel(x, y, color);
    }
  }

  for (var lane = -3; lane <= 3; lane++) {
    drawLine(
      image,
      x1: cx + lane * 90,
      y1: size - 8,
      x2: cx,
      y2: horizonY,
      color: ColorRgba8(31, 107, 58, 140),
      thickness: 4,
    );
  }

  const shipY = 470;
  const shipW = 210.0;
  const shipH = 170.0;

  fillPolygon(
    image,
    vertices: [
      Point(cx, (shipY - shipH * 0.95).round()),
      Point((cx - shipW * 0.55).round(), (shipY + shipH * 0.55).round()),
      Point(cx, (shipY + shipH * 0.2).round()),
      Point((cx + shipW * 0.55).round(), (shipY + shipH * 0.55).round()),
    ],
    color: ColorRgb8(144, 202, 249),
  );

  drawPolygon(
    image,
    vertices: [
      Point(cx, (shipY - shipH * 0.95).round()),
      Point((cx - shipW * 0.55).round(), (shipY + shipH * 0.55).round()),
      Point(cx, (shipY + shipH * 0.2).round()),
      Point((cx + shipW * 0.55).round(), (shipY + shipH * 0.55).round()),
    ],
    color: ColorRgb8(21, 101, 192),
    thickness: 10,
  );

  fillPolygon(
    image,
    vertices: [
      Point((cx - shipW * 0.18).round(), (shipY + shipH * 0.45).round()),
      Point(cx, (shipY + shipH * 0.82).round()),
      Point((cx + shipW * 0.18).round(), (shipY + shipH * 0.45).round()),
    ],
    color: ColorRgb8(255, 112, 67),
  );

  fillCircle(
    image,
    x: (cx - shipW * 0.18).round(),
    y: (shipY - shipH * 0.15).round(),
    radius: 18,
    color: ColorRgba8(224, 247, 255, 220),
  );
  fillCircle(
    image,
    x: (cx + shipW * 0.18).round(),
    y: (shipY - shipH * 0.15).round(),
    radius: 18,
    color: ColorRgba8(224, 247, 255, 220),
  );

  final out = File('assets/app_icon.png');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(encodePng(image));
  stdout.writeln('Icon saved to ${out.path}');
}
