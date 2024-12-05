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
 *
 * BSD 3-Clause License
 *
 * Copyright (c) 2018-2024, the 'flutter_map' authors and maintainers
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 *
 *  Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 *  Neither the name of the copyright holder nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import 'dart:math';
import 'dart:ui';

/// Extension methods for the math.[Point] class
extension PointExtension<T extends num> on Point<T> {
  /// Create new [Point] whose [x] and [y] values are divided by the respective
  /// values in [point].
  Point<double> unscaleBy(Point<num> point) {
    return Point<double>(x / point.x, y / point.y);
  }

  /// Create a new [Point] where the [x] and [y] values are divided by [factor].
  Point<double> operator /(num factor) {
    return Point<double>(x / factor, y / factor);
  }

  /// Create a new [Point] where the [x] and [y] values are rounded to the
  /// nearest integer.
  Point<int> round() {
    return Point<int>(x.round(), y.round());
  }

  /// Create a new [Point] where the [x] and [y] values are rounded up to the
  /// nearest integer.
  Point<int> ceil() {
    return Point<int>(x.ceil(), y.ceil());
  }

  /// Create a new [Point] where the [x] and [y] values are rounded down to the
  /// nearest integer.
  Point<int> floor() {
    return Point<int>(x.floor(), y.floor());
  }

  /// Create a new [Point] whose [x] and [y] values are rotated clockwise by
  /// [radians].
  Point<double> rotate(num radians) {
    if (radians != 0.0) {
      final cosTheta = cos(radians);
      final sinTheta = sin(radians);
      final nx = (cosTheta * x) + (sinTheta * y);
      final ny = (cosTheta * y) - (sinTheta * x);

      return Point<double>(nx, ny);
    }

    return toDoublePoint();
  }

  /// Cast the object to a [Point] object with integer values
  Point<int> toIntPoint() => Point<int>(x.toInt(), y.toInt());

  /// Case the object to a [Point] object with double values
  Point<double> toDoublePoint() => Point<double>(x.toDouble(), y.toDouble());

  /// Maps the [Point] to an [Offset].
  Offset toOffset() => Offset(x.toDouble(), y.toDouble());
}

/// Extension methods for [Offset]
extension OffsetToPointExtension on Offset {
  /// Creates a [Point] representation of this offset.
  Point<double> toPoint() => Point(dx, dy);
}

extension SizeToPointExtensions on Size {
  Point<double> toPoint() => Point(width, height);
}