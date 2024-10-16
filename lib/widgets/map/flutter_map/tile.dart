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

import 'package:flutter/widgets.dart';

import 'tile_builder.dart';
import 'tile_coordinates.dart';
import 'tile_image.dart';

/// The widget for a single tile used for the [TileLayer].
@immutable
class Tile extends StatefulWidget {
  /// [TileImage] is the model class that contains meta data for the Tile image.
  final TileImage tileImage;

  /// The [TileBuilder] is a reference to the [TileLayer]'s
  /// [TileLayer.tileBuilder].
  final TileBuilder? tileBuilder;

  /// The tile size for the given scale of the map.
  final double scaledTileSize;

  final Point<double> currentPixelOffset;

  /// Creates a new instance of [Tile].
  const Tile({
    super.key,
    required this.scaledTileSize,
    required this.currentPixelOffset,
    required this.tileImage,
    required this.tileBuilder,
  });

  TileCoordinates get positionCoordinates => tileImage.coordinates;

  @override
  State<Tile> createState() => _TileState();
}

class _TileState extends State<Tile> {
  @override
  void initState() {
    super.initState();
    widget.tileImage.addListener(_onTileImageChange);
  }

  @override
  void dispose() {
    widget.tileImage.removeListener(_onTileImageChange);
    super.dispose();
  }

  void _onTileImageChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.positionCoordinates.x * widget.scaledTileSize + widget.currentPixelOffset.x,
      top: widget.positionCoordinates.y * widget.scaledTileSize + widget.currentPixelOffset.y,
      width: widget.scaledTileSize,
      height: widget.scaledTileSize,
      child: widget.tileBuilder?.call(context, _tileImage, widget.tileImage) ??
          _tileImage,
    );
  }

  Widget get _tileImage {
    if (widget.tileImage.loadError && widget.tileImage.errorImage != null) {
      return Image(
        image: widget.tileImage.errorImage!,
        opacity: widget.tileImage.opacity == 1
            ? null
            : AlwaysStoppedAnimation(widget.tileImage.opacity),
      );
    } else {
      return RawImage(
        image: widget.tileImage.imageInfo?.image,
        fit: BoxFit.fill,
        opacity: widget.tileImage.opacity == 1
            ? null
            : AlwaysStoppedAnimation(widget.tileImage.opacity),
      );
    }
  }
}