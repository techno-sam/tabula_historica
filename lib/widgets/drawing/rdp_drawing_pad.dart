/*
 * Doodle Tracks
 * Copyright (C) 2024  Sam Wagenaar
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:track_map/logger.dart';

class RDPDrawingPad extends StatelessWidget {
  const RDPDrawingPad({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: const Color(0xFFFFFFF3),
          child: const Center(
            child: Text("Hello world")
          )
        ),
        const _DrawingPad()
      ],
    );
  }
}

class _DrawingPad extends StatefulWidget {
  const _DrawingPad({super.key});

  @override
  State<_DrawingPad> createState() => _DrawingPadState();
}

class _DrawingPadState extends State<_DrawingPad> {
  final List<List<Offset>> _lines = [];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      bottom: 0,
      right: 0,
      child: Listener(
        onPointerDown: (event) {
          logger.i("Pointer down at ${event.localPosition}, buttons: ${event.buttons}");

          if (event.buttons & kSecondaryMouseButton != 0) {
            setState(() {
              _lines.clear();
            });
          } else {
            setState(() {
              _lines.add([event.localPosition]);
            });
          }
        },
        onPointerMove: (event) {
          //logger.i("Pointer move at ${event.localPosition}, buttons: ${event.buttons}");

          if (event.buttons & kSecondaryMouseButton != 0) return;

          setState(() {
            _lines.last.add(event.localPosition);
          });
        },
        child: ClipRect(
          clipBehavior: Clip.hardEdge,
          child: CustomPaint(
            painter: LinesPainter(lines: _lines)
          ),
        ),
      ),
    );
  }
}

class LinesPainter extends CustomPainter {
  final List<List<Offset>> lines;

  LinesPainter({super.repaint, required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    Paint mainPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Paint pointPaint = Paint.from(mainPaint)
      ..color = Colors.deepPurpleAccent.shade100;

    Paint rdpPaint = Paint.from(mainPaint)
      ..color = Colors.red
      ..strokeWidth = 1.0;

    Paint rdpPointPaint = Paint.from(pointPaint)
      ..color = Colors.orangeAccent.shade100;

    Paint bezierRdpPaint = Paint.from(rdpPaint)
      ..color = Colors.greenAccent
      ..strokeWidth = 4.0;

    mainPaint.color = mainPaint.color.withOpacity(0.8);
    pointPaint.color = pointPaint.color.withOpacity(0.5);

    for (List<Offset> line in lines) {
      if (line.isEmpty) continue;

      // draw points
      for (Offset point in line) {
        canvas.drawCircle(Offset(point.dx, point.dy), 3.0, pointPaint);
      }

      Path path = Path();
      path.moveTo(line.first.dx, line.first.dy);
      for (Offset point in line.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, mainPaint);

      List<Offset> simplified = rdpSimplify(line, 2.0);
      for (Offset point in simplified) {
        canvas.drawCircle(point, 3.0, rdpPointPaint);
      }

      Path rdpPath = Path();
      rdpPath.moveTo(simplified.first.dx, simplified.first.dy);
      for (Offset point in simplified.skip(1)) {
        rdpPath.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(rdpPath, rdpPaint);

      _drawCatmullRom(simplified, canvas, bezierRdpPaint, alpha: 0.15, tension: 0.3);
    }
  }

  void _drawBezierThroughPoints(List<Offset> points, Canvas canvas, Paint paint) {
    if (points.length < 2) return;

    Path path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      path.quadraticBezierTo(p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    }
    path.lineTo(points.last.dx, points.last.dy);

    canvas.drawPath(path, paint);
  }

  /// Draw a Catmull-Rom spline through the given points. The spline is drawn onto [canvas] with the given [paint].
  /// The [alpha] parameter controls the tangent bias, 0.0 produces a sharp curve, 1.0 a smoother curve.
  /// The [tension] parameter controls the tightness of the curve by modifying the tangent's length, 0.0 produces a loose curve, 1.0 a tight curve, basically straight lines between each point.
  void _drawCatmullRom(List<Offset> points, Canvas canvas, Paint paint, {double alpha = 0.5, double tension = 0.0}){
    if (points.isEmpty) {
      return;
    } else if (points.length < 2) {
      Paint circlePaint = Paint.from(paint)
      ..strokeWidth = 0
      ..style = PaintingStyle.fill;
      canvas.drawCircle(points.first, paint.strokeWidth/2, circlePaint);
      return;
    }

    Path path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      // Calculate tangents
      final tangent1 = Offset(
        (p2.dx - p0.dx) * alpha,
        (p2.dy - p0.dy) * alpha,
      );
      final tangent2 = Offset(
        (p3.dx - p1.dx) * alpha,
        (p3.dy - p1.dy) * alpha,
      );

      // Adjust tangents based on tension
      final control1 = Offset(
        p1.dx + tangent1.dx * tension,
        p1.dy + tangent1.dy * tension,
      );
      final control2 = Offset(
        p2.dx - tangent2.dx * tension,
        p2.dy - tangent2.dy * tension,
      );

      // Draw cubic Bézier segment
      path.cubicTo(
        control1.dx, control1.dy,
        control2.dx, control2.dy,
        p2.dx, p2.dy,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LinesPainter oldDelegate) => true;
}

List<Offset> rdpSimplify(List<Offset> original, double epsilon) {
  if (original.length < 3) return original;

  // Find the point with the maximum distance
  double dmax = 0;
  int index = 0;
  int end = original.length - 1;
  for (int i = 1; i < end; i++) {
    double d = perpendicularDistance(original[i], original.first, original.last);
    if (d > dmax) {
      index = i;
      dmax = d;
    }
  }

  // If max distance is greater than epsilon, recursively simplify
  if (dmax > epsilon) {
    List<Offset> recResults1 = rdpSimplify(original.sublist(0, index + 1), epsilon);
    List<Offset> recResults2 = rdpSimplify(original.sublist(index), epsilon);

    // build the result list
    List<Offset> result = recResults1.sublist(0, recResults1.length - 1) + recResults2;
    return result;
  } else {
    return [original.first, original.last];
  }
}

double perpendicularDistance(Offset point, Offset lineStart, Offset lineEnd) {
  double dx = lineEnd.dx - lineStart.dx;
  double dy = lineEnd.dy - lineStart.dy;

  // Normalize
  double mag = sqrt(dx * dx + dy * dy);
  dx /= mag;
  dy /= mag;

  double pvx = point.dx - lineStart.dx;
  double pvy = point.dy - lineStart.dy;

  double pvdot = dx * pvx + dy * pvy;
  double ax = pvx - pvdot * dx;
  double ay = pvy - pvdot * dy;

  return sqrt(ax * ax + ay * ay);
}