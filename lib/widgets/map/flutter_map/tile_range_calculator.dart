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

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:track_map/widgets/map/flutter_map/extensions/point.dart';
import 'package:track_map/widgets/map/multi_lod.dart';

import 'bounds.dart';
import 'map_camera.dart';
import 'tile_range.dart';

/// The [TileRangeCalculator] helps to calculate the bounds in pixel.
@immutable
class TileRangeCalculator {
  /// The tile size in pixels.
  final double tileSize;
  final LODCalculator lodCalculator;

  /// Create a new [TileRangeCalculator] instance.
  const TileRangeCalculator({required this.tileSize, required this.lodCalculator});

  /// Calculates the visible pixel bounds at the [tileLOD] zoom level when
  /// viewing the map from the [viewingZoom] centered at the [center]. The
  /// resulting tile range is expanded by panBuffer.
  DiscreteTileRange calculate({
    // The map camera used to calculate the bounds.
    required MapCamera camera,
    // The zoom level at which the bounds should be calculated.
    required int tileLOD,
  }) {
    return DiscreteTileRange.fromPixelBounds(
      lod: tileLOD,
      tileSize: tileSize * lodCalculator.getAdjustedScale(camera.zoom, tileLOD),
      pixelBounds: _calculatePixelBounds(
        camera,
        tileLOD,
      ),
    );
  }

  Bounds<double> _calculatePixelBounds(
    MapCamera camera,
    int tileLOD,
  ) {
    final pixelCenter = const Point(0.0, 0.0) - camera.getOffset(const Point(0, 0)).floor().toDoublePoint();
    final halfSize = camera.size.toPoint() / 2;

    return Bounds(pixelCenter, pixelCenter + halfSize*2);
  }
}