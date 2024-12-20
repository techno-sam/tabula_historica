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

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart' hide Point;
import 'package:provider/provider.dart';

import '../../../extensions/pointer_event.dart';
import '../../../logger.dart';
import '../../../models/project/history_manager.dart';
import '../../../models/tools/tool_selection.dart';
import '../../../models/project/structure.dart';
import '../../../models/tools/structures_state.dart';
import '../../map/flutter_map/map_camera.dart';
import '../../map/flutter_map/extensions/point.dart';

class MapSurfaceStructure extends StatefulWidget {
  const MapSurfaceStructure({super.key});

  @override
  State<MapSurfaceStructure> createState() => _MapSurfaceStructureState();
}

class _MapSurfaceStructureState extends State<MapSurfaceStructure> {
  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final toolSelection = ToolSelection.of(context);
    final history = HistoryManager.of(context);
    final structure = context.read<Structure>();

    final selected = toolSelection.selectedTool == Tool.structures &&
        toolSelection.mapStateOr((StructuresState state) =>
            state.isStructureSelected(structure), false);

    final customPaint = Consumer(
      builder: (context, Structure structure, _) {
        return CustomPaint(
          painter: _MapSurfaceStructurePainter(
            pen: structure.pen,
            strokes: structure.strokes,
            currentStroke: structure.currentStroke,
            camera: camera,
          ),
        );
      }
    );

    final out = SizedBox.expand(
      child: selected
          ? Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (PointerDownEvent event) {
              if (!event.hasPrimaryButton ||
                  event.hasSecondaryButton ||
                  event.hasMiddleButton) {
                return;
              }

              final transformed = camera.getBlockPos(event.localPosition.toPoint()).toOffset();
              structure.startStroke(
                history,
                Width.normal,
                transformed,
              );
            },
            onPointerMove: (PointerMoveEvent event) {
              if (!event.hasPrimaryButton ||
                  event.hasSecondaryButton ||
                  event.hasMiddleButton) {
                return;
              }

              final transformed = camera.getBlockPos(event.localPosition.toPoint()).toOffset();
              structure.updateStroke(
                history,
                transformed,
              );
            },
            onPointerUp: (PointerUpEvent event) {
              structure.endStroke(
                history,
              );
            },
            child: customPaint,
          )
          : customPaint,
    );
    return selected ? out : IgnorePointer(child: out,);
  }
}

class _MapSurfaceStructurePainter extends CustomPainter {
  final Pen pen;
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final MapCamera camera;

  _MapSurfaceStructurePainter({
    required this.pen,
    required this.strokes,
    required this.currentStroke,
    required this.camera,
  });

  void _paintStroke(Canvas canvas, Size size, Paint paint, Stroke stroke, bool completed) {
    if (stroke is CompletedStroke && !stroke.visible(camera)) {
      logger.d("Skipping stroke $stroke because not visible");
      return;
    }

    final strokeOptions = pen.getOptions(
      completed,
      width: stroke.width
    )..size *= structureDetailMultiplier.toDouble();

    final outlinePoints = stroke is CompletedStroke
        ? stroke
            .getUntransformedOutline(strokeOptions)
            .map((p) => camera.getOffset(p.toPoint()).toOffset())
            .toList()
        : getStroke(
            stroke.points
                .map((p) => p * structureDetailMultiplier.toDouble())
                .map((p) => PointVector(p.dx, p.dy))
                .toList(),
            options: strokeOptions,
          )
            .map((e) =>
                camera.getOffset(e.toPoint() / structureDetailMultiplier).toOffset())
            .toList();

    final path = Path();

    if (outlinePoints.isNotEmpty) {
      path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
      for (int i = 1; i < outlinePoints.length - 1; i++) {
        final p0 = outlinePoints[i];
        final p1 = outlinePoints[i + 1];
        path.quadraticBezierTo(
            p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
        ..color = pen.color;

    for (final stroke in strokes) {
      _paintStroke(canvas, size, paint, stroke, true);
    }

    if (currentStroke != null) {
      _paintStroke(canvas, size, paint, currentStroke!, false);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}