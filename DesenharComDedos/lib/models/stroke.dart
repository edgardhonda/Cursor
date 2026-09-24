import 'dart:ui';

class Stroke {
  Stroke({
    required this.color,
    required this.width,
    List<Offset>? points,
  }) : points = points ?? [];

  final Color color;
  final double width;
  final List<Offset> points;

  void addPoint(Offset point) => points.add(point);

  Map<String, dynamic> toJson() {
    final flat = <double>[];
    for (final p in points) {
      flat
        ..add(p.dx)
        ..add(p.dy);
    }
    return {
      'c': color.toARGB32(),
      'w': width,
      'p': flat,
    };
  }

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final flat = (json['p'] as List<dynamic>).cast<num>();
    final points = <Offset>[];
    for (var i = 0; i + 1 < flat.length; i += 2) {
      points.add(Offset(flat[i].toDouble(), flat[i + 1].toDouble()));
    }
    return Stroke(
      color: Color((json['c'] as num).toInt()),
      width: (json['w'] as num).toDouble(),
      points: points,
    );
  }
}
