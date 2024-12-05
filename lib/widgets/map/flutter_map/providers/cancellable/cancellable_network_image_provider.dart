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

import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../../../logger.dart';
import '../../base_tile_provider.dart';

class CancellableNetworkImageProvider
    extends ImageProvider<CancellableNetworkImageProvider> {
  final String url;
  final Map<String, String> headers;
  final Dio dioClient;
  final Future<void> cancelLoading;
  final bool silenceExceptions;
  final void Function() startedLoading;
  final void Function() finishedLoadingBytes;

  const CancellableNetworkImageProvider({
    required this.url,
    required this.headers,
    required this.dioClient,
    required this.cancelLoading,
    required this.silenceExceptions,
    required this.startedLoading,
    required this.finishedLoadingBytes,
  });

  @override
  ImageStreamCompleter loadImage(
      CancellableNetworkImageProvider key,
      ImageDecoderCallback decode,
      ) =>
      MultiFrameImageStreamCompleter(
        codec: _load(key, decode),
        scale: 1,
        debugLabel: url,
        informationCollector: () => [
          DiagnosticsProperty('URL', url),
          DiagnosticsProperty('Current provider', key),
        ],
      );

  Future<Codec> _load(
      CancellableNetworkImageProvider key,
      ImageDecoderCallback decode
      ) async {
    startedLoading();

    final cancelToken = CancelToken();
    unawaited(cancelLoading.then((_) {
      logger.t('Cancelling image request for $url');
      cancelToken.cancel();
    }));

    return dioClient
        .getUri<Uint8List>(
      Uri.parse(url),
      cancelToken: cancelToken,
      options: Options(headers: headers, responseType: ResponseType.bytes),
    )
        .whenComplete(finishedLoadingBytes)
        .then((response) => ImmutableBuffer.fromUint8List(response.data!))
        .then(decode)
        .onError<Exception>((err, stack) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      if (err is DioException && CancelToken.isCancel(err)) {
        return ImmutableBuffer.fromUint8List(TileProvider.transparentImage)
            .then(decode);
      }
      if (!silenceExceptions) throw err;
      return ImmutableBuffer.fromUint8List(TileProvider.transparentImage)
          .then(decode);
    });
  }

  @override
  SynchronousFuture<CancellableNetworkImageProvider> obtainKey(
      ImageConfiguration configuration,
      ) =>
      SynchronousFuture(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is CancellableNetworkImageProvider &&
              url == other.url);

  @override
  int get hashCode =>
      Object.hashAll([url]);
}