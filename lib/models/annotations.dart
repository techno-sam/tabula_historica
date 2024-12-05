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
import 'dart:ui';

class Line extends Iterable<Offset> {
  final List<Offset> points;
  final double strokeWidth;
  final Color color;

  Line({required this.points, required this.strokeWidth, required this.color});

  Line simplified(double epsilon) {
    return Line(points: rdpSimplify(points, epsilon), strokeWidth: strokeWidth, color: color);
  }

  @override
  Iterator<Offset> get iterator => points.iterator;
}

List<Offset> rdpSimplify(List<Offset> original, double epsilon) {
  if (original.length < 3) return original;

  // Find the point with the maximum distance
  double dmax = 0;
  int index = 0;
  int end = original.length - 1;
  for (int i = 1; i < end; i++) {
    double d = _perpendicularDistance(original[i], original.first, original.last);
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

double _perpendicularDistance(Offset point, Offset lineStart, Offset lineEnd) {
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