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
import 'package:perfect_freehand/perfect_freehand.dart';

import '../../../extensions/string.dart';
import '../../../models/project/structure.dart';
import '../../../models/tools/tool_selection.dart';
import '../../../models/tools/structures_state.dart';
import '../tool_specific.dart';

class StructurePenWidthSelector extends StatelessWidget {
  const StructurePenWidthSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ToolSpecificEphemeral(
      tool: Tool.structures,
      builder: (context) {
        return Card.outlined(
          elevation: 1,
          color: theme.colorScheme.surfaceContainerLowest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: SizedBox(
              width: 180,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final width in Width.values)
                    _WidthButton(width: width),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
}

class _WidthButton extends StatelessWidget {
  final Width width;

  const _WidthButton({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolSelection = ToolSelection.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: SizedBox(
        height: 40,
        child: OutlinedButton(
          iconAlignment: IconAlignment.start,
          onPressed: () {
            toolSelection.withState((StructuresState state) {
              state.penWidth = width;
            });
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
            backgroundColor: toolSelection.mapStateOr((StructuresState state) =>
                state.penWidth == width ? theme.colorScheme.surfaceContainerLow : null, null),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _PenPreview(width: width),
              const SizedBox(width: 8),
              Text(
                width.toString().split('.').last.splitCamelCase().toTitleCase(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PenPreview extends StatelessWidget {
  final Width width;

  const _PenPreview({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.colorScheme.onSurfaceVariant,
          width: 1,
        ),
      ),
      child: CustomPaint(
        painter: _PenPreviewPainter(width: width),
      ),
    );
  }
}

class _PenPreviewPainter extends CustomPainter {
  final Width width;

  _PenPreviewPainter({required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black;

    const extraScale = 2.5;
    const margin = 0.175;
    final pts = _previewPoints
      .map((p) => Offset(margin + p.dx * (1 - 2 * margin), margin + p.dy * (1 - 2 * margin)))
      .map((p) => Offset(p.dx * size.width * extraScale, p.dy * size.height * extraScale))
      .map((p) => PointVector(p.dx, p.dy))
      .toList(growable: false);

    final outlinePoints = getStroke(pts,
        options: Pen.building.getOptions(true, width: width)
          ..thinning = 0.0
          ..streamline = 0.0
          ..smoothing = 0.2
          ..simulatePressure = false)
    .map((e) => e.scale(1.0 / extraScale, 1.0 / extraScale))
    .toList(growable: false);

    if (outlinePoints.isEmpty) return;

    final path = Path();

    path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
    for (int i = 1; i < outlinePoints.length - 1; i++) {
      final p0 = outlinePoints[i];
      final p1 = outlinePoints[i + 1];
      path.quadraticBezierTo(
          p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _previewPoints = [
  Offset(0.0, 0.0),
  Offset(0.0004498242342378944, 0.003934687934815884),
  Offset(0.0018105799099430442, 0.015289702452719212),
  Offset(0.004099191166460514, 0.03339146822690964),
  Offset(0.007332582492381334, 0.057566411793231964),
  Offset(0.01152767799794674, 0.08714096248149872),
  Offset(0.01670140214264393, 0.1214415431022644),
  Offset(0.022870680317282677, 0.15979458391666412),
  Offset(0.030052434653043747, 0.20152650773525238),
  Offset(0.03826359286904335, 0.24596373736858368),
  Offset(0.04752107709646225, 0.2924326956272125),
  Offset(0.05784181132912636, 0.3402598202228546),
  Offset(0.06924272328615189, 0.38877153396606445),
  Offset(0.08174072951078415, 0.43729424476623535),
  Offset(0.09535276144742966, 0.485154390335083),
  Offset(0.11009573936462402, 0.5316784381866455),
  Offset(0.12598659098148346, 0.5761927366256714),
  Offset(0.14304223656654358, 0.6180237531661987),
  Offset(0.1612796038389206, 0.6564979553222656),
  Offset(0.1807156205177307, 0.6909416913986206),
  Offset(0.20136719942092896, 0.7206814289093018),
  Offset(0.2232513129711151, 0.7450433373451233),
  Offset(0.24587416648864746, 0.7599009275436401),
  Offset(0.2696172595024109, 0.7633000016212463),
  Offset(0.2943626940250397, 0.7564467191696167),
  Offset(0.3199925422668457, 0.740547239780426),
  Offset(0.34638887643814087, 0.7168077230453491),
  Offset(0.37343376874923706, 0.6864343285560608),
  Offset(0.40100929141044617, 0.6506332159042358),
  Offset(0.42899754643440247, 0.6106105446815491),
  Offset(0.45728060603141785, 0.5675724744796753),
  Offset(0.4857405424118042, 0.5227251648902893),
  Offset(0.5142594575881958, 0.4772747755050659),
  Offset(0.5427193641662598, 0.43242746591567993),
  Offset(0.5710024237632751, 0.38938939571380615),
  Offset(0.5989906787872314, 0.3493667244911194),
  Offset(0.6265661716461182, 0.3135656416416168),
  Offset(0.6536110639572144, 0.2831922769546509),
  Offset(0.6800073981285095, 0.25945279002189636),
  Offset(0.7056372165679932, 0.24355335533618927),
  Offset(0.7303826212882996, 0.2367001324892044),
  Offset(0.754125714302063, 0.24009928107261658),
  Offset(0.7767486572265625, 0.2549566328525543),
  Offset(0.7986327409744263, 0.27931877970695496),
  Offset(0.8192843198776245, 0.3090585172176361),
  Offset(0.8387203216552734, 0.3435022532939911),
  Offset(0.8569576740264893, 0.3819764256477356),
  Offset(0.8740133047103882, 0.42380744218826294),
  Offset(0.8899041414260864, 0.4683217406272888),
  Offset(0.9046471118927002, 0.5148457288742065),
  Offset(0.9182591438293457, 0.5627058744430542),
  Offset(0.9307571649551392, 0.6112285852432251),
  Offset(0.9421581029891968, 0.6597402691841125),
  Offset(0.95247882604599, 0.7075673937797546),
  Offset(0.9617363214492798, 0.7540363669395447),
  Offset(0.9699474573135376, 0.798473596572876),
  Offset(0.9771292209625244, 0.8402054905891418),
  Offset(0.9832984805107117, 0.8785585165023804),
  Offset(0.9884722232818604, 0.9128590822219849),
  Offset(0.9926673173904419, 0.9424336552619934),
  Offset(0.9959006905555725, 0.9666085839271545),
  Offset(0.9981892704963684, 0.9847103357315063),
  Offset(0.9995500445365906, 0.9960653781890869),
  Offset(1.0, 1.0),
];
