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

import 'package:meta/meta.dart';
import 'package:track_map/backend/backend.dart';

import 'tile_coordinates.dart';
import 'tile_range.dart';

/// A bounding box with zoom level.
@immutable
abstract class TileBoundsAtZoom {
  /// Create a new [TileBoundsAtZoom] object.
  const TileBoundsAtZoom();

  /// Returns a list of [TileCoordinates] that are valid because they are within
  /// the [TileRange].
  Iterable<TileCoordinates> validCoordinatesIn(DiscreteTileRange tileRange);
}

/// A infinite tile bounding box.
@immutable
class InfiniteTileBoundsAtZoom extends TileBoundsAtZoom {
  /// Create a new [InfiniteTileBoundsAtZoom] object.
  const InfiniteTileBoundsAtZoom();

  @override
  Iterable<TileCoordinates> validCoordinatesIn(DiscreteTileRange tileRange) =>
      tileRange.coordinates;

  @override
  String toString() => 'InfiniteTileBoundsAtZoom()';
}

/// [TileBoundsAtZoom] that have discrete coordinate bounds.
@immutable
class DiscreteTileBoundsAtZoom extends TileBoundsAtZoom {
  /// The [TileRange] of the [TileBoundsAtZoom].
  final DiscreteTileRange tileRange;

  /// Create a new [DiscreteTileBoundsAtZoom] object.
  const DiscreteTileBoundsAtZoom(this.tileRange);

  @override
  Iterable<TileCoordinates> validCoordinatesIn(DiscreteTileRange tileRange) {
    assert(
    this.tileRange.lod == tileRange.lod,
    "The lod of the provided TileRange can't differ from the lod level of the current tileRange",
    );
    return this.tileRange.intersect(tileRange).coordinates;
  }

  @override
  String toString() => 'DiscreteTileBoundsAtZoom($tileRange)';
}

@immutable
class LODEntryBasedTileBoundsAtZoom extends TileBoundsAtZoom {
  final LodEntry entry;

  const LODEntryBasedTileBoundsAtZoom({required this.entry});

  @override
  Iterable<TileCoordinates> validCoordinatesIn(DiscreteTileRange tileRange) {
    return tileRange.coordinates.where((coordinates) {
      return entry.contains(coordinates);
    });
  }
}
