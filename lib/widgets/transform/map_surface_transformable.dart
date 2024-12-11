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
 */

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_box_transform/flutter_box_transform.dart';
import 'package:tabula_historica/models/tools/tool_selection.dart';

import '../../logger.dart';
import '../../models/transform.dart';
import '../map/flutter_map/extensions/point.dart';
import '../map/flutter_map/map_camera.dart';

class MapTransformableImage extends StatefulWidget {
  const MapTransformableImage({super.key});

  @override
  State<MapTransformableImage> createState() => _MapTransformableImageState();
}

class _MapTransformableImageState extends State<MapTransformableImage> {

  final Transform2D _transform = Transform2D()
    ..translationX = -32
    ..translationY = 16;

  late final int _random;

  bool _activelyResizing = false;
  bool _activelyDragging = false;

  bool get _activelyTransforming => _activelyResizing || _activelyDragging;

  @override
  void initState() {
    super.initState();

    _random = Random().nextInt(100);
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final toolSelection = ToolSelection.of(context);

    final selected = toolSelection.selectedTool == Tool.references;

    const width = 800;
    const height = 450;

    final projectedCenter = camera.getOffset(_transform.translation.toPoint());
    final cameraScale     = pow(2, camera.zoom).toDouble() / 32;
    final scaledWidth     = width  * _transform.scaleX * cameraScale;
    final scaledHeight    = height * _transform.scaleY * cameraScale;

    final rect = Rect.fromCenter(
        center: projectedCenter.toOffset(),
        width: scaledWidth, height: scaledHeight
    );

    final supportedDragDevices = PointerDeviceKind.values
        .toSet()
        .difference({PointerDeviceKind.trackpad});

    bool enabled = selected &&
        !(!_activelyTransforming &&
        ((min(width, height) * cameraScale < 34 && min(scaledWidth, scaledHeight) < 34) ||
        max(scaledWidth, scaledHeight) < 10))
    ;

    return TransformableBox(
      rect: rect,
      flip: Flip.none,
      allowContentFlipping: false,
      allowFlippingWhileResizing: false,
      draggable: enabled,
      resizable: enabled,
      constraints: BoxConstraints(
        minWidth: (width * cameraScale) / 10.0,
        minHeight: (height * cameraScale) / 10.0,
      ),
      supportedDragDevices: supportedDragDevices,
      supportedResizeDevices: supportedDragDevices,

      onChanged: (result, details) {
        setState(() {
          _transform.translation = camera.getBlockPos(result.rect.center.toPoint()).toOffset();
          _transform.scaleX = result.rect.width / width / cameraScale;
          _transform.scaleY = result.rect.height / height / cameraScale;
        });
      },

      onResizeStart: (handle, details) {
        bool wasTransforming = _activelyTransforming;
        _activelyResizing = true;
        if (wasTransforming != _activelyTransforming) {
          setState(() {});
        }
      },
      onResizeEnd: (handle, details) {
        bool wasTransforming = _activelyTransforming;
        _activelyResizing = false;
        if (wasTransforming != _activelyTransforming) {
          setState(() {});
        }
      },
      onResizeCancel: (handle) {
        bool wasTransforming = _activelyTransforming;
        _activelyResizing = false;
        if (wasTransforming != _activelyTransforming) {
          setState(() {});
        }
      },

      onDragStart: (details) {
        bool wasTransforming = _activelyTransforming;
        _activelyDragging = true;
        if (wasTransforming != _activelyTransforming) {
          setState(() {});
        }
      },
      onDragEnd: (details) {
        bool wasTransforming = _activelyTransforming;
        _activelyDragging = false;
        if (wasTransforming != _activelyTransforming) {
          setState(() {});
        }
      },
      onDragCancel: () {
        bool wasTransforming = _activelyTransforming;
        _activelyDragging = false;
        if (wasTransforming != _activelyTransforming) {
          setState(() {});
        }
      },

      contentBuilder: (context, rect, flip) => GestureDetector(
        onDoubleTap: enabled ? () {
          // Reset aspect ratio
          setState(() {
            final averageScale = (_transform.scaleX + _transform.scaleY) / 2;
            _transform.scaleX = averageScale;
            _transform.scaleY = averageScale;
          });
        } : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? (enabled
                    ? Colors.blue
                    : Colors.blue.shade700)
                  : Colors.black,
              width: 2,
            ),
          ),
          child: Image.network(
            "https://picsum.photos/$width/$height?random=$_random",
            width: rect.width,
            height: rect.height,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}