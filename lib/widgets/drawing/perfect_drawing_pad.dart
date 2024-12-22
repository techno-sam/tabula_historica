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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart' hide Point;
import 'package:tabula_historica/extensions/pointer_event.dart';
import 'package:tabula_historica/models/tools/tool_selection.dart';
import 'package:tabula_historica/widgets/map/flutter_map/extensions/point.dart';

import '../map/flutter_map/map_camera.dart';

const int _detailMultiplier = 2;

class PerfectDrawingPad extends StatefulWidget {
  const PerfectDrawingPad({super.key});

  @override
  State<PerfectDrawingPad> createState() => _PerfectDrawingPadState();
}

class _PerfectDrawingPadState extends State<PerfectDrawingPad> {
  final List<List<PointVector>> lines = [];

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final toolSelection = ToolSelection.of(context);

    final customPaint = CustomPaint(
      painter: _PerfectDrawingPainter(lines, camera.getOffset),
    );

    final out = SizedBox.expand(
      child: Container(
        /*decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          border: Border.all(color: Colors.greenAccent, width: 2),
        ),*/
        child: toolSelection.selectedTool == Tool.structures
            ? Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (PointerDownEvent event) {
                if (!event.hasPrimaryButton ||
                    event.hasSecondaryButton ||
                    event.hasMiddleButton) {
                  return;
                }
                setState(() {
                  final line = <PointVector>[];
                  lines.add(line);
                  final transformed = camera.getBlockPos(event.localPosition.toPoint()) * _detailMultiplier;
                  line.add(PointVector(transformed.x, transformed.y));
                });
              },
              onPointerMove: (PointerMoveEvent event) {
                if (!event.hasPrimaryButton ||
                    event.hasSecondaryButton ||
                    event.hasMiddleButton) {
                  return;
                }
                if (lines.isNotEmpty) {
                  setState(() {
                    final line = lines.last;
                    final transformed = camera.getBlockPos(event.localPosition.toPoint()) * _detailMultiplier;
                    line.add(PointVector(transformed.x, transformed.y));
                  });
                }
              },
              child: customPaint,
            )
            : customPaint,
      ),
    );
    return toolSelection.selectedTool == Tool.structures ? out : IgnorePointer(child: out);
  }
}

class _PerfectDrawingPainter extends CustomPainter {
  final List<List<PointVector>> lines;
  final Point<double> Function(Point<double>) transformer;

  _PerfectDrawingPainter(List<List<PointVector>> lines, this.transformer):
        lines = List<List<PointVector>>.unmodifiable(
            lines.map((e) => List<PointVector>.unmodifiable(e))
        );

  @override
  void paint(Canvas canvas, Size size) {
    final StrokeOptions strokeOptions = StrokeOptions(
      isComplete: false,
      streamline: 0.15,
      smoothing: 0.3,
      thinning: 0.6,
      size: (8 * _detailMultiplier).toDouble(), // default for now
    );

    final Paint paint = Paint()
      ..color = Colors.black;
    /*final Paint pointPaint = Paint()
      ..color = Colors.blue;*/

    for (final line in lines) {
      final outlinePoints = getStroke(line, options: strokeOptions)
      .map((e) => transformer(e.toPoint() / _detailMultiplier).toOffset())
      .toList();
      final path = Path();

      if (outlinePoints.isEmpty) {
        continue;
      } else {
        path.moveTo(outlinePoints[0].dx, outlinePoints[0].dy);

        for (int i = 1; i < outlinePoints.length - 1; ++i) {
          final p0 = outlinePoints[i];
          final p1 = outlinePoints[i + 1];
          path.quadraticBezierTo(
              p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
          }
      }

      /*for (final point in line) {
        final pt = transformer(point.toPoint() / _detailMultiplier).toOffset();
        canvas.drawCircle(pt, 5, pointPaint);
      }*/

      canvas.drawPath(path, paint);

      // canvas.drawCircle(const Offset(0, 0), 20, Paint()..color = Colors.blue);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}