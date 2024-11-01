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

import 'dart:collection';

import 'tile_coordinates.dart';
import 'tile_image.dart';
import 'tile_range.dart';

/// The [TileImageView] stores all loaded [TileImage]s with their
/// [TileCoordinates].
final class TileImageView {
  final Map<TileCoordinates, TileImage> _tileImages;
  final Set<TileCoordinates> _positionCoordinates;
  final DiscreteTileRange _visibleRange;
  final DiscreteTileRange _keepRange;

  /// Create a new [TileImageView] instance.
  const TileImageView({
    required Map<TileCoordinates, TileImage> tileImages,
    required Set<TileCoordinates> positionCoordinates,
    required DiscreteTileRange visibleRange,
    required DiscreteTileRange keepRange,
  })  : _tileImages = tileImages,
        _positionCoordinates = positionCoordinates,
        _visibleRange = visibleRange,
        _keepRange = keepRange;

  /// Get a list with all tiles that have an error and are outside of the
  /// margin that should get kept.
  List<TileCoordinates> errorTilesOutsideOfKeepMargin() =>
      _errorTilesWithinRange(_keepRange);

  /// Get a list with all tiles that are not visible on the current map
  /// viewport.
  List<TileCoordinates> errorTilesNotVisible() =>
      _errorTilesWithinRange(_visibleRange);

  /// Get a list with all tiles that are not visible on the current map
  /// viewport.
  List<TileCoordinates> _errorTilesWithinRange(DiscreteTileRange range) {
    final List<TileCoordinates> result = <TileCoordinates>[];
    for (final positionCoordinates in _positionCoordinates) {
      if (range.contains(positionCoordinates)) {
        continue;
      }
      final TileImage? tileImage =
      _tileImages[positionCoordinates];
      if (tileImage?.loadError ?? false) {
        result.add(positionCoordinates);
      }
    }
    return result;
  }

  /// Get a list of [TileImage] that are stale and can get for pruned.
  Iterable<TileCoordinates> get staleTiles {
    final stale = HashSet<TileCoordinates>();
    final retain = HashSet<TileCoordinates>();

    for (final positionCoordinates in _positionCoordinates) {
      if (!_keepRange.contains(positionCoordinates)) {
        stale.add(positionCoordinates);
        continue;
      }

      final retainedAncestor = _retainAncestor(
        retain,
        positionCoordinates.x,
        positionCoordinates.y,
        positionCoordinates.lod,
        positionCoordinates.lod - 5,
      );
      if (!retainedAncestor) {
        _retainChildren(
          retain,
          positionCoordinates.x,
          positionCoordinates.y,
          positionCoordinates.lod,
          positionCoordinates.lod + 2,
        );
      }
    }

    return stale.where((tile) => !retain.contains(tile));
  }

  /// Get a list of [TileCoordinates] that need to get rendered on screen.
  Iterable<TileCoordinates> get renderTiles {
    final retain = HashSet<TileCoordinates>();

    for (final positionCoordinates in _positionCoordinates) {
      if (!_visibleRange.contains(positionCoordinates)) {
        continue;
      }

      retain.add(positionCoordinates);

      final TileImage? tile = _tileImages[positionCoordinates];
      if (tile == null || !tile.readyToDisplay) {
        final retainedAncestor = _retainAncestor(
          retain,
          positionCoordinates.x,
          positionCoordinates.y,
          positionCoordinates.lod,
          positionCoordinates.lod - 5,
        );
        if (!retainedAncestor) {
          _retainChildren(
            retain,
            positionCoordinates.x,
            positionCoordinates.y,
            positionCoordinates.lod,
            positionCoordinates.lod + 2,
          );
        }
      }
    }
    return retain;
  }

  /// Recurse through the ancestors of the Tile at the given coordinates adding
  /// them to [retain] if they are ready to display or loaded. Returns true if
  /// any of the ancestor tiles were ready to display.
  bool _retainAncestor(
      Set<TileCoordinates> retain,
      int x,
      int y,
      int lod,
      int minLod,
      ) {
    final x2 = (x / 2).floor();
    final y2 = (y / 2).floor();
    final lod2 = lod - 1;
    final coords2 = TileCoordinates(x: x2, y: y2, lod: lod2);

    final tile = _tileImages[coords2];
    if (tile != null) {
      if (tile.readyToDisplay) {
        retain.add(coords2);
        return true;
      } else if (tile.loadFinishedAt != null) {
        retain.add(coords2);
      }
    }

    if (lod2 > minLod) {
      return _retainAncestor(retain, x2, y2, lod2, minLod);
    }

    return false;
  }

  /// Recurse through the descendants of the Tile at the given coordinates
  /// adding them to [retain] if they are ready to display or loaded.
  void _retainChildren(
      Set<TileCoordinates> retain,
      int x,
      int y,
      int lod,
      int maxLod,
      ) {
    for (final (i, j) in const [(0, 0), (0, 1), (1, 0), (1, 1)]) {
      final lod2 = lod + 1;
      final coords = TileCoordinates(x: 2 * x + i, y: 2 * y + j, lod: lod2);

      final tile = _tileImages[coords];
      if (tile != null) {
        if (tile.readyToDisplay || tile.loadFinishedAt != null) {
          retain.add(coords);

          // If have the child, we do not recurse. We don't need the child's children.
          continue;
        }
      }

      if (lod2 < maxLod) {
        _retainChildren(retain, i, j, lod2, maxLod);
      }
    }
  }
}