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

import 'package:collection/collection.dart';
import 'tile_bounds_at_zoom.dart';
import 'tile_coordinates.dart';
import 'tile_error_evict_callback.dart';
import 'tile_image.dart';
import 'tile_image_view.dart';
import 'tile_range.dart';
import 'package:meta/meta.dart';

/// Callback definition to crete a [TileImage] for [TileCoordinates].
typedef TileCreator = TileImage Function(TileCoordinates coordinates);

/// The [TileImageManager] orchestrates the loading and pruning of tiles.
@immutable
class TileImageManager {
  final Set<TileCoordinates> _positionCoordinates = HashSet<TileCoordinates>();

  final Map<TileCoordinates, TileImage> _tiles =
  HashMap<TileCoordinates, TileImage>();

  /// Check if the [TileImageManager] has the tile for a given tile coordinates.
  bool containsTileAt(TileCoordinates coordinates) =>
      _positionCoordinates.contains(coordinates);

  /// Check if all tile images are loaded
  bool get allLoaded =>
      _tiles.values.none((tile) => tile.loadFinishedAt == null);

  /// Check if all visible tile images are loaded
  bool allVisibleTilesLoaded(DiscreteTileRange visibleRange) => _tiles.values.none((tile) => visibleRange.contains(tile.coordinates) && tile.loadFinishedAt == null);

  /// Filter tiles to only tiles that would be visible on screen. Specifically:
  ///   1. Tiles in the visible range at the target zoom level.
  ///   2. Tiles at non-target zoom level that would cover up holes that would
  ///      be left by tiles in #1, which are not ready yet.
  Iterable<TileImage> getTilesToRender({
    required DiscreteTileRange visibleRange,
  }) {
    final Iterable<TileCoordinates> positionCoordinates = TileImageView(
      tileImages: _tiles,
      positionCoordinates: _positionCoordinates,
      visibleRange: visibleRange,
      // `keepRange` is irrelevant here since we're not using the output for
      // pruning storage but rather to decide on what to put on screen.
      keepRange: visibleRange,
    ).renderTiles;
    final List<TileImage> tileRenderers = <TileImage>[];
    for (final position in positionCoordinates) {
      final TileImage? tileImage = _tiles[position];
      if (tileImage != null) {
        tileRenderers.add(tileImage);
      }
    }
    return tileRenderers;
  }

  /// Creates missing [TileImage]s within the provided tile range. Returns a
  /// list of [TileImage]s which haven't started loading yet.
  List<TileImage> createMissingTiles(
      DiscreteTileRange tileRange,
      TileBoundsAtZoom tileBoundsAtZoom, {
        required TileCreator createTile,
      }) {
    final notLoaded = <TileImage>[];

    for (final coordinates in tileBoundsAtZoom.validCoordinatesIn(tileRange)) {
      TileImage? tile = _tiles[coordinates];
      if (tile == null) {
        tile = createTile(coordinates);
        _tiles[coordinates] = tile;
      }
      _positionCoordinates.add(coordinates);
      if (tile.loadStarted == null) {
        notLoaded.add(tile);
      }
    }

    return notLoaded;
  }

  void clearAllTiles() {
    for (final coordinates in [..._positionCoordinates]) {
      _remove(coordinates, evictImageFromCache: (_) => true);
    }
  }

  /// All removals should be performed by calling this method to ensure that
  /// disposal is performed correctly.
  void _remove(
      TileCoordinates key, {
        required bool Function(TileImage tileImage) evictImageFromCache,
      }) {
    _positionCoordinates.remove(key);

    // guard if positionCoordinates with the same tileImage.
    for (final positionCoordinates in _positionCoordinates) {
      if (positionCoordinates == key) {
        return;
      }
    }

    final removed = _tiles.remove(key);

    if (removed != null) {
      removed.dispose(evictImageFromCache: evictImageFromCache(removed));
    }
  }

  void _removeWithEvictionStrategy(
      TileCoordinates key,
      EvictErrorTileStrategy strategy,
      ) {
    _remove(
      key,
      evictImageFromCache: (tileImage) =>
      tileImage.loadError && strategy != EvictErrorTileStrategy.none,
    );
  }

  /// Remove all tiles with a given [EvictErrorTileStrategy].
  void removeAll(EvictErrorTileStrategy evictStrategy) {
    final keysToRemove = List<TileCoordinates>.from(_positionCoordinates);

    for (final key in keysToRemove) {
      _removeWithEvictionStrategy(key, evictStrategy);
    }
  }

  /// evict tiles that have an error and prune tiles that are no longer needed.
  /// Returns a list of [TileCoordinates] that were pruned.
  Iterable<TileCoordinates> evictAndPrune({
    required DiscreteTileRange visibleRange,
    required int pruneBuffer,
    required EvictErrorTileStrategy evictStrategy,
  }) {
    final pruningState = TileImageView(
      tileImages: _tiles,
      positionCoordinates: _positionCoordinates,
      visibleRange: visibleRange,
      keepRange: visibleRange.expand(pruneBuffer),
    );

    _evictErrorTiles(pruningState, evictStrategy);
    return _prune(pruningState, evictStrategy);
  }

  void _evictErrorTiles(
      TileImageView tileRemovalState,
      EvictErrorTileStrategy evictStrategy,
      ) {
    switch (evictStrategy) {
      case EvictErrorTileStrategy.notVisibleRespectMargin:
        for (final coordinates
        in tileRemovalState.errorTilesOutsideOfKeepMargin()) {
          _remove(coordinates, evictImageFromCache: (_) => true);
        }
      case EvictErrorTileStrategy.notVisible:
        for (final coordinates in tileRemovalState.errorTilesNotVisible()) {
          _remove(coordinates, evictImageFromCache: (_) => true);
        }
      case EvictErrorTileStrategy.dispose:
      case EvictErrorTileStrategy.none:
        return;
    }
  }

  /// Prune tiles from the [TileImageManager].
  /// Returns a list of [TileCoordinates] that were pruned.
  Iterable<TileCoordinates> prune({
    required DiscreteTileRange visibleRange,
    required int pruneBuffer,
    required EvictErrorTileStrategy evictStrategy,
  }) {
    return _prune(
      TileImageView(
        tileImages: _tiles,
        positionCoordinates: _positionCoordinates,
        visibleRange: visibleRange,
        keepRange: visibleRange.expand(pruneBuffer),
      ),
      evictStrategy,
    );
  }

  /// Prune tiles from the [TileImageManager].
  /// Returns a list of [TileCoordinates] that were pruned.
  Iterable<TileCoordinates> _prune(
      TileImageView tileRemovalState,
      EvictErrorTileStrategy evictStrategy,
      ) {
    final out = <TileCoordinates>[];
    for (final coordinates in tileRemovalState.staleTiles) {
      _removeWithEvictionStrategy(coordinates, evictStrategy);
      out.add(coordinates);
    }
    return out;
  }
}