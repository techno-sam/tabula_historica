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

import 'dart:ui';

extension EpsilonDifference on double {
  bool differs(double other, double epsilon) => (this - other).abs() > epsilon;
}

extension InfiniteToNull on double {
  double? infiniteToNull() => isFinite ? this : null;
}

extension YearDateUtil on int {
  String yearDateToString() {
    return abs().toString() + (this < 0 ? ' BCE' : ' CE');
  }
}

extension ClampableOffset on Offset {
  Offset clampToRect(Rect rect) {
    return Offset(
      dx.clamp(rect.left, rect.right),
      dy.clamp(rect.top, rect.bottom),
    );
  }
}
