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

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart' hide Point;
import 'package:provider/provider.dart';
import 'package:tabula_historica/extensions/color_manipulation.dart';
import 'package:tabula_historica/models/structure_info_selection.dart';
import 'package:tabula_historica/widgets/map/widgets/map_surface_positioned.dart';

import '../../../extensions/pointer_event.dart';
import '../../../models/project/history_manager.dart';
import '../../../models/tools/tool_selection.dart';
import '../../../models/project/structure.dart';
import '../../../models/tools/structures_state.dart';
import '../../map/flutter_map/map_camera.dart';
import '../../map/flutter_map/extensions/point.dart';

class MapSurfaceStructureLabel extends StatelessWidget {
  final bool infoButton;
  const MapSurfaceStructureLabel({super.key, this.infoButton = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final structure = context.watch<Structure>();

    if (structure.pen != Pen.building || !structure.fullBounds.isFinite ||
        structure.fullBounds.isEmpty) {
      return const SizedBox();
    }

    final camera = MapCamera.of(context);
    final transformedOutline = camera.getOffsetRect(structure.fullBounds);
    if (!transformedOutline.overlaps(Offset.zero & camera.size)) {
      return const SizedBox();
    }

    Offset position = structure.fullBounds.center;
    if (structure.fullBounds.width * structure.fullBounds.width + structure.fullBounds.height * structure.fullBounds.height < (20*20)) {
      position = structure.fullBounds.topCenter - const Offset(0, 2);
    }

    final contents = Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 4.0, horizontal: 8.0),
      child: Text(
        structure.titleForDisplayNoSubtitle,
        style: theme.textTheme.labelLarge,
      ),
    );

    final card = Card.outlined(
      color: theme.colorScheme.surfaceContainerLowest,
      // black outline
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: theme.colorScheme.surfaceContainerLowest.invert(),
          width: 1.0,
        ),
      ),
      child: infoButton ?
      InkWell(
        onTap: () {
          StructureInfoSelection.of(context, listen: false).selectedStructure = structure;
        },
        borderRadius: BorderRadius.circular(8.0),
        child: contents,
      ) :
      contents,
    );

    return MapSurfacePositioned(
      x: position.dx,
      y: position.dy,
      baseScale: 0.25,
      halfHeight: 20,
      // determine halfWidth based on length of title
      halfWidth: 20 + structure.titleForDisplayNoSubtitle.length * 4,
      child: infoButton ? card : IgnorePointer(child: card),
    );
  }
}

class MapSurfaceStructure extends StatelessWidget {
  const MapSurfaceStructure({super.key});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final toolSelection = ToolSelection.of(context);
    final history = HistoryManager.of(context);
    final structure = context.watch<Structure>();

    final selected = toolSelection.selectedTool == Tool.structures &&
        toolSelection.mapStateOr((StructuresState state) =>
            state.isStructureSelected(structure), false);

    final penWidth = toolSelection.mapStateOr((StructuresState state) => state.penWidth, Width.normal);

    final customPaint = CustomPaint(
      painter: _MapSurfaceStructurePainter(
        pen: structure.pen,
        strokes: structure.strokes,
        currentStroke: structure.currentStroke,
        selected: selected,
        camera: camera,
      ),
    );

    Widget out = SizedBox.expand(
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
                penWidth,
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
              structure.updateStroke(transformed);
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

    final transformedOutline = camera.getOffsetRect(structure.fullBounds.inflate(6.0)).inflate(2.0);
    if (transformedOutline.isFinite && selected) {
      out = Stack(
        children: [
          Positioned.fromRect(
            rect: transformedOutline,
            child: DottedBorder(
              color: structure.timePeriod.color,
              borderType: BorderType.RRect,
              radius: const Radius.circular(8.0),
              dashPattern: const [8, 8],
              child: const SizedBox(),
            ),
          ),
          out,
        ],
      );
    }
    return selected ? out : IgnorePointer(child: out,);
  }
}

class StaticMapSurfaceStructure extends StatelessWidget {
  const StaticMapSurfaceStructure({super.key});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final structure = context.watch<Structure>();

    return SizedBox.expand(
      child: CustomPaint(
        painter: _MapSurfaceStructurePainter(
          pen: structure.pen,
          strokes: structure.strokes,
          currentStroke: structure.currentStroke,
          selected: false,
          camera: camera,
        ),
      ),
    );
  }
}

class _MapSurfaceStructurePainter extends CustomPainter {
  final Pen pen;
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final bool selected;
  final MapCamera camera;

  _MapSurfaceStructurePainter({
    required this.pen,
    required this.strokes,
    required this.currentStroke,
    required this.selected,
    required this.camera,
  });

  void _paintStroke(Canvas canvas, Size size, Paint paint, Stroke stroke, bool completed) {
    if (stroke is CompletedStroke && !stroke.visible(camera)) return;

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

    if (selected && pen != Pen.building) {
      final Paint selectedPaint = Paint()
        ..color = pen.color.withValues(alpha: 1.0).invert().lighten(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;

      for (final stroke in strokes) {
        _paintStroke(canvas, size, selectedPaint, stroke, true);
      }

      if (currentStroke != null) {
        _paintStroke(canvas, size, selectedPaint, currentStroke!, false);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}