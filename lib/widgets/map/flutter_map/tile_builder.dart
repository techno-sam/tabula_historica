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

import 'package:flutter/material.dart';

import 'tile_image.dart';

/// Builder function that returns a [TileBuilder] instance.
typedef TileBuilder = Widget Function(
    BuildContext context, Widget tileWidget, TileImage tile);

/// Shows coordinates over Tiles
Widget coordinateDebugTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
    ) {
  final coordinates = tile.coordinates;
  final readableKey = '${coordinates.x} : ${coordinates.y} : ${coordinates.lod}';

  return DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(),
    ),
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        tileWidget,
        Center(
          child: Text(
            readableKey,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    ),
  );
}

/// Shows the Tile loading time in ms
Widget loadingTimeDebugTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
    ) {
  final loadStarted = tile.loadStarted;
  final loaded = tile.loadFinishedAt;

  final time = loaded == null
      ? 'Loading'
      : '${(loaded.millisecond - loadStarted!.millisecond).abs()} ms';

  return DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(),
    ),
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        tileWidget,
        Center(
          child: Text(
            time,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    ),
  );
}

// Show coordinates and the Tile loading time over tiles
Widget coordinateAndLoadingTimeDebugTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
    ) {
  final coordinates = tile.coordinates;
  final readableKey = '${coordinates.x} : ${coordinates.y} : ${coordinates
      .lod}';
  final loadStarted = tile.loadStarted;
  final loaded = tile.loadFinishedAt;

  final time = loaded == null
      ? 'Loading'
      : '${(loaded.millisecond - loadStarted!.millisecond).abs()} ms';

  return DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(),
    ),
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        tileWidget,
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  readableKey,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  time,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            )
          ),
        )
      ],
    )
  );
}