import 'dart:io';
import 'dart:math';

import 'package:image/image.dart';

/// Gera assets/app_icon.png — robô estilo infantil (contorno preto).
void main() {
  const size = 1024;
  final image = Image(width: size, height: size);
  fill(image, color: ColorRgb8(255, 255, 255));

  const cx = size ~/ 2;
  const cy = size ~/ 2 + 30;
  const scale = 5.2;

  void line(double x1, double y1, double x2, double y2, {int thickness = 14}) {
    drawLine(
      image,
      x1: (cx + x1 * scale).round(),
      y1: (cy + y1 * scale).round(),
      x2: (cx + x2 * scale).round(),
      y2: (cy + y2 * scale).round(),
      color: ColorRgb8(0, 0, 0),
      thickness: thickness,
    );
  }

  void rect(double left, double top, double right, double bottom) {
    line(left, top, right, top);
    line(right, top, right, bottom);
    line(right, bottom, left, bottom);
    line(left, bottom, left, top);
  }

  const s = 56.0;

  // corpo
  rect(-s * 0.24, -s * 0.26, s * 0.24, s * 0.26);
  // cabeça
  rect(-s * 0.17, -s * 0.45, s * 0.17, -s * 0.27);
  // antenas
  line(-s * 0.1, -s * 0.45, -s * 0.1, -s * 0.58);
  line(s * 0.1, -s * 0.45, s * 0.1, -s * 0.58);
  // olhos
  fillCircle(
    image,
    x: (cx - s * 0.09 * scale).round(),
    y: (cy - s * 0.34 * scale).round(),
    radius: (s * 0.045 * scale).round(),
    color: ColorRgb8(0, 0, 0),
  );
  fillCircle(
    image,
    x: (cx + s * 0.09 * scale).round(),
    y: (cy - s * 0.34 * scale).round(),
    radius: (s * 0.045 * scale).round(),
    color: ColorRgb8(0, 0, 0),
  );
  // braços
  line(-s * 0.24, -s * 0.02, -s * 0.42, -s * 0.18, thickness: 12);
  line(s * 0.24, -s * 0.02, s * 0.42, -s * 0.18, thickness: 12);
  // pernas
  line(-s * 0.14, s * 0.26, -s * 0.14, s * 0.5, thickness: 12);
  line(s * 0.14, s * 0.26, s * 0.14, s * 0.5, thickness: 12);

  final out = File('assets/app_icon.png');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(encodePng(image));
  stdout.writeln('Icon saved to ${out.path}');
}
