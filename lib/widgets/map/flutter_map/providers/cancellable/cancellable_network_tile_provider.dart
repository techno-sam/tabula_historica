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

import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';
import 'package:track_map/widgets/map/flutter_map/base_tile_provider.dart';
import 'package:track_map/widgets/map/flutter_map/tile_coordinates.dart';

import 'cancellable_network_image_provider.dart';

/// [TileProvider] that fetches tiles from the network, with the capability to
/// cancel unnecessary HTTP tile requests
///
/// {@template fmctp-desc}
///
/// Tiles that are removed/pruned before they are fully loaded do not need to
/// complete (down)loading, and therefore do not need to complete the HTTP
/// interaction. Cancelling these unnecessary tile requests early could:
///
/// - Reduce tile loading durations (particularly on the web)
/// - Reduce users' (cellular) data and cache space consumption
/// - Reduce costly tile requests to tile servers*
/// - Improve performance by reducing CPU and IO work
///
/// This provider uses '[dio](https://pub.dev/packages/dio)', which supports
/// aborting unnecessary HTTP requests in-flight, after they have already been
/// sent.
///
/// Although HTTP request abortion is supported on all platforms, it is
/// especially useful on the web - and therefore recommended for web apps. This
/// is because the web platform has a limited number of simulatous HTTP requests,
/// and so closing the requests allows new requests to be made for new tiles.
/// On other platforms, the other benefits may still occur, but may not be as
/// visible as on the web.
///
/// Once HTTP request abortion is
/// [added to Dart's 'native' 'http' package (which already has a PR opened)](https://github.com/dart-lang/http/issues/424),
/// `NetworkTileProvider` will be updated to take advantage of it, replacing and
/// deprecating this provider. This tile provider is currently a seperate package
/// and not the default due to the reliance on the additional Dio dependency.
///
/// ---
///
/// On the web, the 'User-Agent' header cannot be changed as specified in
/// [TileLayer.tileProvider]'s documentation, due to a Dart/browser limitation.
///
/// The [silenceExceptions] argument controls whether to ignore exceptions and
/// errors that occur whilst fetching tiles over the network, and just return a
/// transparent tile.
/// {@endtemplate}
base class CancellableNetworkTileProvider extends TileProvider {
  /// Create a [CancellableNetworkTileProvider] to fetch tiles from the network,
  /// with cancellation support
  ///
  /// {@macro fmctp-desc}
  CancellableNetworkTileProvider({
    super.headers,
    Dio? dioClient,
    this.silenceExceptions = false,
  }) : _dioClient = dioClient ?? Dio();

  /// Whether to ignore exceptions and errors that occur whilst fetching tiles
  /// over the network, and just return a transparent tile
  final bool silenceExceptions;

  /// Long living client used to make all tile requests by [CancellableNetworkImageProvider]
  /// for the duration that this provider is alive
  final Dio _dioClient;

  /// Each [Completer] is completed once the corresponding tile has finished
  /// loading
  ///
  /// Used to avoid disposing of [_dioClient] whilst HTTP requests are still
  /// underway.
  ///
  /// Does not include tiles loaded from session cache.
  final _tilesInProgress = HashMap<TileCoordinates, Completer<void>>();

  @override
  bool get supportsCancelLoading => true;

  @override
  ImageProvider getImageWithCancelLoadingSupport(
      TileCoordinates coordinates,
      Future<void> cancelLoading,
      ) =>
      CancellableNetworkImageProvider(
        url: getTileUrl(coordinates),
        headers: headers,
        dioClient: _dioClient,
        cancelLoading: cancelLoading,
        silenceExceptions: silenceExceptions,
        startedLoading: () => _tilesInProgress[coordinates] = Completer(),
        finishedLoadingBytes: () {
          _tilesInProgress[coordinates]?.complete();
          _tilesInProgress.remove(coordinates);
        },
      );

  @override
  Future<void> dispose() async {
    if (_tilesInProgress.isNotEmpty) {
      await Future.wait(_tilesInProgress.values.map((c) => c.future));
    }
    _dioClient.close();
    super.dispose();
  }
}