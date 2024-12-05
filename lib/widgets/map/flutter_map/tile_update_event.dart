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

import 'package:meta/meta.dart';

import 'map_camera.dart';

/// Describes whether loading and/or pruning should occur.
@immutable
class TileUpdateEvent {
  final MapCamera camera;

  /// Set to true if the tiles should get loaded.
  final bool load;

  /// Set to true if the tiles should get pruned.
  final bool prune;

  /// Create a new [TileUpdateEvent].
  const TileUpdateEvent({
    required this.camera,
    this.load = true,
    this.prune = true,
  });

  /// Returns a copy of this TileUpdateEvent with only pruning enabled.
  TileUpdateEvent pruneOnly() => TileUpdateEvent(
    camera: camera,
    load: false,
  );

  /// Returns a copy of this TileUpdateEvent with only loading enabled.
  TileUpdateEvent loadOnly() => TileUpdateEvent(
    camera: camera,
    prune: false,
  );

  /// Returns a copy of this TileUpdateEvent with loading and pruning enabled.
  TileUpdateEvent loadAndPrune() => TileUpdateEvent(
    camera: camera,
  );

  @override
  String toString() =>
      'TileUpdateEvent(camera: $camera, load: $load, prune: $prune)';
}