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

import 'package:flutter/widgets.dart';

import '../../../logger.dart';

import 'tile_coordinates.dart';

/// The tile image class
class TileImage extends ChangeNotifier {
  bool _disposed = false;

  /// Whether the tile is displayable. See [readyToDisplay].
  bool _readyToDisplay = false;

  /// The z of the coordinate is the TileImage's zoom level whilst the x and y
  /// indicate the position of the tile at that zoom level.
  final TileCoordinates coordinates;

  /// Callback fired when loading finishes with or without an error. This
  /// callback is not triggered after this TileImage is disposed.
  final void Function(TileCoordinates coordinates) onLoadComplete;

  /// Callback fired when an error occurs whilst loading the tile image.
  /// [onLoadComplete] will be called immediately afterwards. This callback is
  /// not triggered after this TileImage is disposed.
  final void Function(TileImage tile, Object error, StackTrace? stackTrace) onLoadError;

  /// An optional image to show when a loading error occurs.
  final ImageProvider? errorImage;

  /// Completer that is completed when this object is disposed
  ///
  /// Intended to allow [TileProvider]s to cancel unneccessary HTTP requests.
  final Completer<void> cancelLoading;

  /// [ImageProvider] that loads the image.
  ImageProvider imageProvider;

  /// True if an error occurred during loading.
  bool loadError = false;

  /// When loading started.
  DateTime? loadStarted;

  /// When loading finished.
  DateTime? loadFinishedAt;

  /// Some meta data of the image.
  ImageInfo? imageInfo;
  ImageStream? _imageStream;
  late ImageStreamListener _listener;

  /// Create a new object for a tile image.
  TileImage({
    required this.coordinates,
    required this.imageProvider,
    required this.onLoadComplete,
    required this.onLoadError,
    required this.errorImage,
    required this.cancelLoading,
  });

  /// Get the current opacity value for the tile image.
  double get opacity => _readyToDisplay ? 1.0 : 0.0;

  /// Whether the tile is displayable. This means that either:
  ///   * Loading errored but an error image is configured.
  ///   * Loading succeeded and the fade animation has finished.
  ///   * Loading succeeded and there is no fade animation.
  ///
  /// Note that [opacity] can be less than 1 when this is true if instantaneous
  /// tile display is used with a maximum opacity less than 1.
  bool get readyToDisplay => _readyToDisplay;

  /// Initiate loading of the image.
  void load() {
    if (cancelLoading.isCompleted) return;

    loadStarted = DateTime.now();

    try {
      final oldImageStream = _imageStream;
      _imageStream = imageProvider.resolve(ImageConfiguration.empty);

      if (_imageStream!.key != oldImageStream?.key) {
        oldImageStream?.removeListener(_listener);

        _listener = ImageStreamListener(
          _onImageLoadSuccess,
          onError: _onImageLoadError,
        );
        _imageStream!.addListener(_listener);
      }
    } catch (e, s) {
      // Make sure all exceptions are handled - #444 / #536
      _onImageLoadError(e, s);
    }
  }

  void _onImageLoadSuccess(ImageInfo imageInfo, bool synchronousCall) {
    loadError = false;
    this.imageInfo = imageInfo;

    if (!_disposed) {
      _display();
      onLoadComplete(coordinates);
    }
  }

  void _onImageLoadError(Object exception, StackTrace? stackTrace) {
    loadError = true;

    if (!_disposed) {
      if (errorImage != null) _display();
      onLoadError(this, exception, stackTrace);
      onLoadComplete(coordinates);
    }
  }

  // Initiates fading in and marks this TileImage as readyToDisplay when fading
  // finishes. If fading is disabled or a loading error occurred this TileImage
  // becomes readyToDisplay immediately.
  void _display() {
    loadFinishedAt = DateTime.now();

    if (loadError) {
      assert(
      errorImage != null,
      'A TileImage should not be displayed if loading errors and there is no '
          'errorImage to show.',
      );
      _readyToDisplay = true;
      if (!_disposed) notifyListeners();
      return;
    }

    _readyToDisplay = true;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose({bool evictImageFromCache = false}) {
    assert(
    !_disposed,
    'The TileImage dispose() method was called multiple times',
    );
    _disposed = true;

    if (evictImageFromCache) {
      try {
        imageProvider.evict().catchError((Object e) {
          logger.e("Failed to evict image from cache", error: e);
          return false;
        });
      } catch (e) {
        // This may be never called because catchError will handle errors, however
        // we want to avoid random crashes like in #444 / #536
        logger.e("Unexpected error when evicting image from cache", error: e);
      }
    }

    cancelLoading.complete();

    _readyToDisplay = false;
    notifyListeners();

    _imageStream?.removeListener(_listener);
    super.dispose();
  }

  @override
  int get hashCode => coordinates.hashCode;

  @override
  bool operator ==(Object other) {
    return other is TileImage && coordinates == other.coordinates;
  }

  @override
  String toString() {
    return 'TileImage($coordinates, readyToDisplay: $_readyToDisplay)';
  }
}