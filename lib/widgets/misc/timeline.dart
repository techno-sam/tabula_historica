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
import 'package:provider/provider.dart';

import 'package:tabula_historica/extensions/numeric.dart';
import '../../models/timeline.dart';

class TimelineCard extends StatelessWidget {
  const TimelineCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = Colors.grey.shade800;

    var sliderStyle = theme.sliderTheme.copyWith(
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
      showValueIndicator: ShowValueIndicator.always,
      valueIndicatorShape: const DropSliderValueIndicatorShape(),
      trackShape: const RectangularSliderTrackShape(),
      activeTrackColor: color,
      inactiveTrackColor: color,
    );

    return Card.outlined(
      elevation: 1,
      color: theme.colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0, right: 4.0, top: 6.0),
        child: Consumer(
          builder: (BuildContext context, Timeline timeline, Widget? child) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: CustomPaint(
                    size: const Size(double.infinity, 60),
                    painter: TickedTimelinePainter(
                      min: timeline.minYear.toDouble(),
                      max: timeline.maxYear.toDouble(),
                      color: color,
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: SliderTheme(
                    data: sliderStyle,
                    child: Slider(
                      key: const Key('timeline_slider'),
                      min: timeline.minYear.toDouble(),
                      max: timeline.maxYear.toDouble(),
                      value: timeline.selectedYear.toDouble(),
                      onChanged: (value) {
                        timeline.selectedYear = value.toInt();
                      },
                      label: timeline.selectedYear.yearDateToString(),
                    ),
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}

class TickedTimelinePainter extends CustomPainter {
  final double min;
  final double max;
  final Color color;

  TickedTimelinePainter({
    required this.min,
    required this.max,
    required this.color
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;

    const majorTickHeight = 32.0;
    const semiMinorTickHeight = 24.0;
    const minorTickHeight = 16.0;

    for (double i = min; i <= max; i += 10) {
      final x = (i - min) / (max - min) * size.width;
      final isMajorTick = i % 100 == 0;
      final isSemiMinorTick = i % 50 == 0;

      double tickHeight = isMajorTick
          ? majorTickHeight
          : (isSemiMinorTick
          ? semiMinorTickHeight
          : minorTickHeight);

      canvas.drawLine(
        Offset(x, (size.height / 2 - 10) - (tickHeight / 2)),
        Offset(x, (size.height / 2 - 10) + (tickHeight / 2)),
        paint,
      );

      if (isMajorTick || isSemiMinorTick) {
        final textSpan = TextSpan(
          text: i.toInt().yearDateToString(),
          style: TextStyle(color: color, fontSize: isMajorTick ? 12 : 10),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, (size.height + majorTickHeight) / 2 - 5));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
