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
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'extensions/point.dart';
import 'tile_update_event.dart';

class MapCamera extends ChangeNotifier {
  Point<double> _blockPosCenter;
  double _zoom;
  Size _size;

  final _mapEventStreamController = StreamController<TileUpdateEvent>.broadcast();
  Stream<TileUpdateEvent> get updateStream => _mapEventStreamController.stream;

  int _batchDepth = 0;
  bool _notifyOnExit = false;

  MapCamera({required Point<double> blockPosCenter, required double zoom, required Size size})
      : _blockPosCenter = blockPosCenter,
        _zoom = zoom,
        _size = size;

  Point<double> get blockPosCenter => _blockPosCenter;
  double get zoom => _zoom;
  Size get size => _size;

  void asBatchOperation(void Function() operation) {
    _batchDepth++;
    operation();
    _batchDepth--;
    if (_batchDepth == 0 && _notifyOnExit) {
      _notifyUpdate();
      _notifyOnExit = false;
    }
  }

  bool get isInBatchOperation => _batchDepth > 0;

  set blockPosCenter(Point<double> blockPosCenter){
    if (_blockPosCenter == blockPosCenter) return;
    _blockPosCenter = blockPosCenter;
    _notifyUpdate();
  }

  set zoom(double zoom){
    if (_zoom == zoom) return;
    _zoom = zoom;
    _notifyUpdate();
  }

  set size(Size size){
    if (_size == size) return;
    _size = size;
    _notifyUpdate();
  }

  void _notifyUpdate() {
    if (isInBatchOperation) {
      _notifyOnExit = true;
      return;
    }
    _mapEventStreamController.add(TileUpdateEvent(camera: this));
    notifyListeners();
  }

  Point<double> getOffset(Point<double> blockPos) {
    Point<double> offset = blockPosCenter - blockPos;
    return (size.toPoint() / 2) - (offset * pow(2, zoom).toDouble() * 256);
  }

  Point<double> getBlockPos(Point<double> screenSpace) {
    Point<double> offset = (size.toPoint() / 2) - screenSpace;
    Point<double> blockPos = blockPosCenter - (offset / (pow(2, zoom).toDouble() * 256));
    return blockPos;
  }

  static MapCamera of(BuildContext context, {bool listen = true}) {
    return Provider.of(context, listen: listen);
  }

  @override
  String toString() {
    return 'MapCamera(blockPosCenter: $blockPosCenter, zoom: $zoom, size: $size)';
  }
}