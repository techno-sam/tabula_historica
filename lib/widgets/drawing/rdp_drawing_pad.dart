/*
 * Tabula Historica
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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/annotations.dart';
import '../../logger.dart';

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
  const _DrawingPad();

  @override
  State<_DrawingPad> createState() => _DrawingPadState();
}

class _DrawingPadState extends State<_DrawingPad> {
  final List<Line> _lines = [];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      bottom: 0,
      right: 0,
      child: Listener(
        onPointerDown: (event) {
          logger.d("Pointer down at ${event.localPosition}, buttons: ${event.buttons}");

          if (event.buttons & kSecondaryMouseButton != 0) {
            setState(() {
              _lines.clear();
            });
          } else {
            setState(() {
              _lines.add(Line(points: [event.localPosition], strokeWidth: 3.0, color: Colors.greenAccent));
            });
          }
        },
        onPointerMove: (event) {
          //logger.i("Pointer move at ${event.localPosition}, buttons: ${event.buttons}");

          if (event.buttons & kSecondaryMouseButton != 0) return;

          setState(() {
            _lines.last.points.add(event.localPosition);
          });
        },
        child: ClipRect(
          clipBehavior: Clip.hardEdge,
          child: CustomPaint(
            painter: CatmullRomPainter(lines: _lines)
          ),
        ),
      ),
    );
  }
}

const bool _debugOriginal = false;
const bool _debugSimplified = false;

class CatmullRomPainter extends CustomPainter {
  final List<Line> lines;

  CatmullRomPainter({super.repaint, required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    Paint mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Paint originalPaint = Paint.from(mainPaint)
      ..color = Colors.blue.withValues(alpha: 0.8)
      ..strokeWidth = 2.0;

    Paint originalPointPaint = Paint.from(mainPaint)
      ..color = Colors.deepPurpleAccent.shade100.withValues(alpha: 0.5)
      ..strokeWidth = 2.0;

    Paint rdpPaint = Paint.from(mainPaint)
      ..color = Colors.red
      ..strokeWidth = 1.0;

    Paint rdpPointPaint = Paint.from(mainPaint)
      ..color = Colors.orangeAccent.shade100
      ..strokeWidth = 2.0;

    for (Line line in lines) {
      if (line.isEmpty) continue;

      Line simplified = line.simplified(2.0);

      if (_debugOriginal) {
        // draw points
        for (Offset point in line) {
          canvas.drawCircle(
              Offset(point.dx, point.dy), 3.0, originalPointPaint);
        }

        Path path = Path();
        path.moveTo(line.first.dx, line.first.dy);
        for (Offset point in line.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, originalPaint);
      }

      if (_debugSimplified) {
        for (Offset point in simplified) {
          canvas.drawCircle(point, 3.0, rdpPointPaint);
        }

        Path rdpPath = Path();
        rdpPath.moveTo(simplified.first.dx, simplified.first.dy);
        for (Offset point in simplified.skip(1)) {
          rdpPath.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(rdpPath, rdpPaint);
      }

      mainPaint
        ..strokeWidth = line.strokeWidth
        ..color = line.color;
      _drawCatmullRom(simplified.points, canvas, mainPaint, alpha: 0.25, tension: 0.3);
    }
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
  bool shouldRepaint(covariant CatmullRomPainter oldDelegate) => true;
}
