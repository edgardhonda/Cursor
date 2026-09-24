import 'dart:io';

import 'package:image/image.dart';

/// Gera assets/app_icon.png — um pequeno castelo (silhueta preta).
void main() {
  const size = 1024;
  final image = Image(width: size, height: size);
  fill(image, color: ColorRgb8(255, 255, 255));

  final black = ColorRgb8(0, 0, 0);
  final white = ColorRgb8(255, 255, 255);

  // Muro
  fillRect(image, x1: 170, y1: 560, x2: 854, y2: 824, color: black);

  // Ameias do muro (merlões no topo)
  const wallLeft = 170;
  const wallSpan = 684;
  for (var i = 0; i < 5; i++) {
    final x = wallLeft + (i * wallSpan / 5).round();
    fillRect(
      image,
      x1: x,
      y1: 500,
      x2: x + (wallSpan / 10).round(),
      y2: 560,
      color: black,
    );
  }

  // Torre central
  fillRect(image, x1: 410, y1: 360, x2: 614, y2: 824, color: black);

  // Telhado triangular
  fillPolygon(
    image,
    vertices: [Point(376, 362), Point(512, 196), Point(648, 362)],
    color: black,
  );

  // Porta (recorte branco)
  fillRect(image, x1: 468, y1: 666, x2: 556, y2: 824, color: white);

  // Janela (recorte branco)
  fillRect(image, x1: 484, y1: 428, x2: 540, y2: 500, color: white);

  // Mastro + bandeira
  drawLine(image, x1: 512, y1: 196, x2: 512, y2: 132, color: black, thickness: 8);
  fillPolygon(
    image,
    vertices: [Point(512, 132), Point(588, 156), Point(512, 182)],
    color: black,
  );

  final out = File('assets/app_icon.png');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(encodePng(image));
  stdout.writeln('Icon saved to ${out.path}');
}
