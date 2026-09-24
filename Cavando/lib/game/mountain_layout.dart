import 'dart:math' as math;
import 'dart:ui';

/// Volcano that fills the available screen: base edge-to-edge, peak near the top.
class MountainLayout {
  MountainLayout(this.size) {
    peakX = size.width * 0.50;
    peakY = size.height * 0.035;
    baseY = size.height * 0.92;

    leftOutline = _map([
      const Offset(0.465, 0.055),
      const Offset(0.42, 0.14),
      const Offset(0.34, 0.28),
      const Offset(0.22, 0.48),
      const Offset(0.10, 0.68),
      const Offset(0.02, 0.84),
      const Offset(0.00, 0.92),
    ]);
    rightOutline = _map([
      const Offset(0.535, 0.055),
      const Offset(0.58, 0.14),
      const Offset(0.66, 0.28),
      const Offset(0.78, 0.48),
      const Offset(0.90, 0.68),
      const Offset(0.98, 0.84),
      const Offset(1.00, 0.92),
    ]);

    bodyPath = Path()
      ..moveTo(0, baseY)
      ..lineTo(leftOutline.last.dx, leftOutline.last.dy);
    for (var i = leftOutline.length - 2; i >= 0; i--) {
      bodyPath.lineTo(leftOutline[i].dx, leftOutline[i].dy);
    }
    bodyPath.lineTo(peakX - size.width * 0.028, peakY + size.height * 0.012);
    bodyPath.lineTo(peakX + size.width * 0.028, peakY + size.height * 0.012);
    for (final p in rightOutline) {
      bodyPath.lineTo(p.dx, p.dy);
    }
    bodyPath
      ..lineTo(size.width, baseY)
      ..close();

    snowPath = _buildSnow();
    craterPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(peakX, peakY + size.height * 0.018),
          width: size.width * 0.09,
          height: size.height * 0.028,
        ),
      );

    shadePath = Path()
      ..moveTo(peakX, peakY)
      ..lineTo(size.width, baseY)
      ..lineTo(peakX, baseY)
      ..close();

    peakRidge = _map([
      const Offset(0.39, 0.155),
      const Offset(0.43, 0.10),
      const Offset(0.47, 0.058),
      const Offset(0.50, 0.048),
      const Offset(0.53, 0.058),
      const Offset(0.57, 0.10),
      const Offset(0.61, 0.155),
    ]);

    leftSlope = [
      for (final p in leftOutline)
        Offset(p.dx - size.width * 0.012, p.dy),
    ];
    rightSlope = [
      for (final p in rightOutline)
        Offset(p.dx + size.width * 0.012, p.dy),
    ];
  }

  final Size size;
  late final double peakX;
  late final double peakY;
  late final double baseY;
  late final Path bodyPath;
  late final Path snowPath;
  late final Path craterPath;
  late final Path shadePath;
  late final List<Offset> leftOutline;
  late final List<Offset> rightOutline;
  late final List<Offset> leftSlope;
  late final List<Offset> rightSlope;
  late final List<Offset> peakRidge;

  bool contains(Offset p) => bodyPath.contains(p);

  bool inSnow(Offset p) => snowPath.contains(p);

  double get ridgeLeft => peakRidge.first.dx;
  double get ridgeRight => peakRidge.last.dx;

  double ridgeYAt(double x) => _polylineY(peakRidge, x);

  Offset closestOnRidge(Offset p) => closestOnPolyline(peakRidge, p);

  Offset pointOnSlope(bool left, double t) {
    return _pointOnPolyline(left ? leftSlope : rightSlope, t.clamp(0.0, 1.0));
  }

  double progressOnSlope(bool left, Offset p) {
    return _progressOnPolyline(left ? leftSlope : rightSlope, p);
  }

  double distanceToRidge(Offset p) => (closestOnRidge(p) - p).distance;

  double distanceToSlope(bool left, Offset p) {
    final poly = left ? leftSlope : rightSlope;
    return (closestOnPolyline(poly, p) - p).distance;
  }

  Path _buildSnow() {
    final jag = _map([
      const Offset(0.37, 0.22),
      const Offset(0.395, 0.33),
      const Offset(0.43, 0.21),
      const Offset(0.46, 0.36),
      const Offset(0.50, 0.20),
      const Offset(0.54, 0.35),
      const Offset(0.57, 0.22),
      const Offset(0.605, 0.32),
      const Offset(0.63, 0.22),
    ]);
    final path = Path()
      ..moveTo(peakX - size.width * 0.03, peakY + size.height * 0.01);
    path.lineTo(jag.first.dx, jag.first.dy);
    for (var i = 1; i < jag.length; i++) {
      path.lineTo(jag[i].dx, jag[i].dy);
    }
    path.lineTo(peakX + size.width * 0.03, peakY + size.height * 0.01);
    path.close();
    return path;
  }

  List<Offset> _map(List<Offset> n) {
    return [
      for (final p in n) Offset(p.dx * size.width, p.dy * size.height),
    ];
  }
}

Offset closestOnPolyline(List<Offset> pts, Offset p) {
  var best = pts.first;
  var bestD = double.infinity;
  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i];
    final b = pts[i + 1];
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    final t = len2 == 0 ? 0.0 : ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    final c = a + ab * t.clamp(0.0, 1.0);
    final d = (c - p).distanceSquared;
    if (d < bestD) {
      bestD = d;
      best = c;
    }
  }
  return best;
}

double _polylineY(List<Offset> pts, double x) {
  if (x <= pts.first.dx) return pts.first.dy;
  if (x >= pts.last.dx) return pts.last.dy;
  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i];
    final b = pts[i + 1];
    if (x >= a.dx && x <= b.dx) {
      final t = (x - a.dx) / (b.dx - a.dx).clamp(0.0001, double.infinity);
      return a.dy + (b.dy - a.dy) * t;
    }
  }
  return pts.last.dy;
}

Offset _pointOnPolyline(List<Offset> pts, double t) {
  final lengths = _segmentLengths(pts);
  final total = lengths.fold<double>(0, (a, b) => a + b);
  var remain = total * t;
  for (var i = 0; i < pts.length - 1; i++) {
    final seg = lengths[i];
    if (remain <= seg || i == pts.length - 2) {
      final u = seg == 0 ? 0.0 : (remain / seg).clamp(0.0, 1.0);
      return pts[i] + (pts[i + 1] - pts[i]) * u;
    }
    remain -= seg;
  }
  return pts.last;
}

double _progressOnPolyline(List<Offset> pts, Offset p) {
  final closest = closestOnPolyline(pts, p);
  final lengths = _segmentLengths(pts);
  final total = lengths.fold<double>(0, (a, b) => a + b);
  if (total == 0) return 0;
  var walked = 0.0;
  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i];
    final b = pts[i + 1];
    final ab = b - a;
    final len = lengths[i];
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) continue;
    final t = ((closest - a).dx * ab.dx + (closest - a).dy * ab.dy) / len2;
    final proj = a + ab * t.clamp(0.0, 1.0);
    if ((proj - closest).distanceSquared < 1.5) {
      return ((walked + t.clamp(0.0, 1.0) * len) / total).clamp(0.0, 1.0);
    }
    walked += len;
  }
  return (p - pts.last).distance < (p - pts.first).distance ? 1 : 0;
}

List<double> _segmentLengths(List<Offset> pts) {
  return [
    for (var i = 0; i < pts.length - 1; i++) (pts[i + 1] - pts[i]).distance,
  ];
}

double clampDouble(double v, double min, double max) =>
    math.max(min, math.min(max, v));
