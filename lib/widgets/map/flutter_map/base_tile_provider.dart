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

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'tile_coordinates.dart';

/// The base tile provider, extended by other classes with more specialised
/// purposes and/or requirements
///
/// Prefer extending over implementing.
///
/// For more information, see
/// <https://docs.fleaflet.dev/explanation#tile-providers>, and
/// <https://docs.fleaflet.dev/layers/tile-layer/tile-providers>. For an example
/// extension (with custom [ImageProvider]), see [NetworkTileProvider].
abstract class TileProvider {
  /// Custom HTTP headers that may be sent with each tile request
  ///
  /// Non-networking implementations may ignore this property.
  ///
  /// [TileLayer] will usually automatically set the 'User-Agent' header, based
  /// on the `userAgentPackageName`, but this can be overridden. On the web, this
  /// header cannot be changed, as specified in [TileLayer.tileProvider]'s
  /// documentation, due to a Dart/browser limitation.
  final Map<String, String> headers;

  /// Indicates to flutter_map internals whether to call [getImage] (when
  /// `false`) or [getImageWithCancelLoadingSupport]
  ///
  /// The appropriate method must be overriden, else an [UnimplementedError]
  /// will be thrown.
  ///
  /// [getImageWithCancelLoadingSupport] is designed to allow for implementations
  /// that can cancel HTTP requests or other processing in-flight, when the
  /// underlying tile is disposed before it is loaded. This may increase
  /// performance, and may decrease unnecessary tile requests. Note that this
  /// only applies to the web platform. For more information, and detailed
  /// implementation expectations, see documentation on
  /// [getImageWithCancelLoadingSupport].
  ///
  /// [getImage] does not support cancellation.
  ///
  /// Defaults to `false`. Only needs to be overridden where
  /// [getImageWithCancelLoadingSupport] is in use.
  bool get supportsCancelLoading => false;

  /// Construct the base tile provider and initialise the [headers] property
  ///
  /// This is not a constant constructor, and does not use an initialising
  /// formal, intentionally. To enable [TileLayer] to efficiently (without
  /// [headers] being non-final or unstable `late`) inject the appropriate
  /// 'User-Agent' (based on what is specified by the user), the [headers] [Map]
  /// must not be constant.
  ///
  /// Extenders should add `super.headers` to their constructors if they support
  /// custom HTTP headers. However, they should not provide a constant default
  /// value.
  TileProvider({Map<String, String>? headers}) : headers = headers ?? {};

  /// Retrieve a tile as an image, based on its coordinates and the [TileLayer]
  ///
  /// Usually redirects to a custom [ImageProvider], with one input depending on
  /// [getTileUrl].
  ///
  /// For many implementations, this is the only method that will need
  /// implementing.
  ///
  /// ---
  ///
  /// Does not support cancelling loading tiles, unlike
  /// [getImageWithCancelLoadingSupport]. For this method to be called instead of
  /// that, [supportsCancelLoading] must be `false` (default).
  ImageProvider getImage(TileCoordinates coordinates) {
    throw UnimplementedError(
      'A `TileProvider` that does not override `supportsCancelLoading` to `true` '
          'must override `getImage`',
    );
  }

  /// Retrieve a tile as an image, based on its coordinates and the [TileLayer]
  ///
  /// For this method to be called instead of [getImage], [supportsCancelLoading]
  /// must be overriden to `true`.
  ///
  /// Usually redirects to a custom [ImageProvider], with one parameter using
  /// [getTileUrl], and one using [cancelLoading].
  ///
  /// For many implementations, this is the only method that will need
  /// implementing.
  ///
  /// ---
  ///
  /// Supports cancelling loading tiles, which is designed to allow for
  /// implementations that can cancel HTTP requests or other processing
  /// in-flight, when the underlying tile is disposed before it is loaded. This
  /// may increase performance, and may decrease unnecessary tile requests. Note
  /// that this only applies to the web platform.
  ///
  /// The [cancelLoading] future will complete when the underlying tile is
  /// disposed/pruned. The implementation should therefore listen for its
  /// completion, then cancel the loading. If an image [Codec] is required,
  /// decode [transparentImage] - it will never be visible anyway. Note that
  /// [cancelLoading] will always be completed on disposal, even if the tile has
  /// been fully loaded, but this side effect is not usually an issue.
  ///
  /// See this example with 'package:dio's `CancelToken`:
  ///
  /// ```dart
  /// final cancelToken = CancelToken();
  /// cancelLoading.then((_) => cancelToken.cancel());
  /// ```
  ImageProvider getImageWithCancelLoadingSupport(
      TileCoordinates coordinates,
      Future<void> cancelLoading,
      ) {
    throw UnimplementedError(
      'A `TileProvider` that overrides `supportsCancelLoading` to `true` must '
          'override `getImageWithCancelLoadingSupport`',
    );
  }

  /// Called when the [TileLayer] is disposed
  ///
  /// When disposing resources, ensure that they are not currently being used
  /// by tiles in progress.
  void dispose() {}

  /// Generate a primary URL for a tile, based on its coordinates
  String getTileUrl(TileCoordinates coordinates) => "http://localhost:80/map_data/${coordinates.lod}/x${coordinates.x}/z${coordinates.y}.png";

  /// [Uint8List] that forms a fully transparent image
  ///
  /// Intended to be used with [getImageWithCancelLoadingSupport], so that a
  /// cancelled tile load returns this. It will not be displayed. An error cannot
  /// be thrown from a custom [ImageProvider].
  static final transparentImage = Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);
}