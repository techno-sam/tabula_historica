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
import 'package:tabula_historica/widgets/map/flutter_map/extensions/point.dart';
import 'package:tabula_historica/widgets/map/flutter_map/map_camera.dart';

class MapGridPaper extends StatelessWidget {
  const MapGridPaper({super.key});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    return CustomPaint(
      painter: _MapGridPaperPainter(
        originOffset: camera.getOffset(const Point(0, 0)).toOffset(),
        scale: pow(2, camera.zoom).toDouble(),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MapGridPaperPainter extends CustomPainter {
  final Offset originOffset;
  final double scale;

  _MapGridPaperPainter({required this.originOffset, required this.scale});

  static const double rawInterval = 1000;
  static const int divisions = 10;      // every 100m
  static const int subDivisions = 10;   // every 10m
  static const int superDivisions = 10; // every 1m

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final double width = size.width;
    final double height = size.height;

    final double originX = originOffset.dx;
    final double originY = originOffset.dy;

    final double scaledInterval = rawInterval * scale;

    int verticalLineCellCount = (width / scaledInterval / 2).ceil();
    int horizontalLineCellCount = (height / scaledInterval / 2).ceil();

    void renderGrid(int lineCount, void Function(double offset) render) {
      for (int major = -lineCount; major <= lineCount; major++) {
        for (int semiMajor = 0; semiMajor < divisions; semiMajor++) {
          for (int minor = 0; minor < subDivisions; minor++) {
            for (int ultraMinor = 0; ultraMinor < superDivisions; ultraMinor++) {
              double offset = 0
                  + major * scaledInterval
                  + semiMajor * (scaledInterval / divisions)
                  + minor * (scaledInterval / (divisions * subDivisions))
                  + ultraMinor * (scaledInterval / (divisions * subDivisions * superDivisions));
              paint.strokeWidth = (semiMajor == 0 && minor == 0 && ultraMinor == 0)
                  ? 4.0
                  : ((minor == 0 && ultraMinor == 0)
                  ? 2.0
                  : ((ultraMinor == 0) ? 1.0 : 0.5)
              );
              paint.color = (semiMajor == 0 && minor == 0 && ultraMinor == 0)
                  ? Colors.black87
                  : ((minor == 0 && ultraMinor == 0)
                  ? Colors.black54
                  : ((ultraMinor == 0) ? Colors.black38 : Colors.black12)
              );
              render(offset);
              // canvas.drawLine(Offset(x, 0), Offset(x, height), paint);
              if (scaledInterval / (divisions * subDivisions * superDivisions) < 10) {
                break;
              }
            }
            if (scaledInterval / (divisions * subDivisions) < 10) {
              break;
            }
          }
          if (scaledInterval / (divisions) < 10) {
            break;
          }
        }
      }
    }

    renderGrid(verticalLineCellCount, (offset) {
      offset += originX;
      canvas.drawLine(Offset(offset, 0), Offset(offset, height), paint);
    });

    renderGrid(horizontalLineCellCount, (offset) {
      offset += originY;
      canvas.drawLine(Offset(0, offset), Offset(width, offset), paint);
    });
  }

  @override
  bool shouldRepaint(covariant _MapGridPaperPainter oldPainter) {
    return oldPainter.originOffset != originOffset || oldPainter.scale != scale;
  }
}