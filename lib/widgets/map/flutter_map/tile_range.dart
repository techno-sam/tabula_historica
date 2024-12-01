/*
 * Doodle Tracks
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

import 'dart:math' as math hide Point;
import 'dart:math' show Point;

import 'package:meta/meta.dart';

import 'extensions/point.dart';
import 'bounds.dart';

import 'tile_coordinates.dart';

/// A range of tiles, this is normally a [DiscreteTileRange] and sometimes
/// a [EmptyTileRange].
@immutable
abstract class TileRange {
  /// The lod level, 0 is all the way zoomed in, inf is all the way zoomed out
  final int lod;

  /// The base constructor the the abstract [TileRange] class.
  const TileRange(this.lod);

  /// Get the list of coordinates for the range of tiles.
  Iterable<TileCoordinates> get coordinates;
}

/// A subclass of [TileRange] that just returns an empty [Iterable] if the
/// [coordinates] getter gets used.
@immutable
class EmptyTileRange extends TileRange {
  const EmptyTileRange._(super.lod);

  @override
  Iterable<TileCoordinates> get coordinates =>
      const Iterable<TileCoordinates>.empty();
}

/// Every [TileRange] is a [DiscreteTileRange] if it's not an [EmptyTileRange].
@immutable
class DiscreteTileRange extends TileRange {
  /// Bounds are inclusive
  final Bounds<int> _bounds;

  /// Create a new [DiscreteTileRange] by setting it's values.
  const DiscreteTileRange(super.lod, this._bounds);

  /// Calculate a [DiscreteTileRange] by using the pixel bounds.
  factory DiscreteTileRange.fromPixelBounds({
    required int lod,
    required double tileSize,
    required Bounds<double> pixelBounds,
  }) {
    final Bounds<int> bounds;
    if (pixelBounds.min == pixelBounds.max) {
      final minAndMax = (pixelBounds.min / tileSize).floor();
      bounds = Bounds<int>(minAndMax, minAndMax);
    } else {
      bounds = Bounds<int>(
        (pixelBounds.min / tileSize).floor(),
        (pixelBounds.max / tileSize).ceil() - const Point(1, 1),
      );
    }

    return DiscreteTileRange(lod, bounds);
  }

  /// Expand the [DiscreteTileRange] by a given amount in every direction.
  DiscreteTileRange expand(int count) {
    if (count == 0) return this;

    return DiscreteTileRange(
      lod,
      _bounds
          .extend(Point<int>(_bounds.min.x - count, _bounds.min.y - count))
          .extend(Point<int>(_bounds.max.x + count, _bounds.max.y + count)),
    );
  }

  /// return the [TileRange] after this tile range got intersected with an
  /// [other] tile range.
  TileRange intersect(DiscreteTileRange other) {
    final boundsIntersection = _bounds.intersect(other._bounds);

    if (boundsIntersection == null) return EmptyTileRange._(lod);

    return DiscreteTileRange(lod, boundsIntersection);
  }

  /// Inclusive
  TileRange intersectX(int minX, int maxX) {
    if (_bounds.min.x > maxX || _bounds.max.x < minX) {
      return EmptyTileRange._(lod);
    }

    return DiscreteTileRange(
      lod,
      Bounds<int>(
        Point<int>(math.max(min.x, minX), min.y),
        Point<int>(math.min(max.x, maxX), max.y),
      ),
    );
  }

  /// Inclusive
  TileRange intersectY(int minY, int maxY) {
    if (_bounds.min.y > maxY || _bounds.max.y < minY) {
      return EmptyTileRange._(lod);
    }

    return DiscreteTileRange(
      lod,
      Bounds<int>(
        Point<int>(min.x, math.max(min.y, minY)),
        Point<int>(max.x, math.min(max.y, maxY)),
      ),
    );
  }

  /// Check if a [Point] is inside of the bounds of the [DiscreteTileRange].
  bool contains(TileCoordinates point) {
    bool containsCoordinate(int value, int min, int max) {
      return value >= min && value <= max;
    }

    return point.lod == lod && containsCoordinate(point.x, min.x, max.x) &&
        containsCoordinate(point.y, min.y, max.y);
  }

  /// The minimum [Point] of the [DiscreteTileRange]
  Point<int> get min => _bounds.min;

  /// The maximum [Point] of the [DiscreteTileRange]
  Point<int> get max => _bounds.max;

  /// The center [Point] of the [DiscreteTileRange]
  Point<double> get center => _bounds.center;

  /// Get a list of [TileCoordinates] for the [DiscreteTileRange].
  @override
  Iterable<TileCoordinates> get coordinates sync* {
    for (var j = _bounds.min.y; j <= _bounds.max.y; j++) {
      for (var i = _bounds.min.x; i <= _bounds.max.x; i++) {
        yield TileCoordinates(lod: lod, x: i, y: j);
      }
    }
  }

  @override
  String toString() => 'DiscreteTileRange($min, $max)';
}