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
import 'package:provider/provider.dart';
import 'package:tabula_historica/extensions/numeric.dart';

import '../../../models/project/history_manager.dart';
import '../../../models/project/reference.dart';
import '../../../models/tools/tool_selection.dart';
import '../../../models/tools/references_state.dart';
import '../../../models/transform.dart';
import '../../map/flutter_map/extensions/point.dart';
import '../../map/flutter_map/map_camera.dart';
import '../../misc/blend_mask.dart';

class MapTransformableReference extends StatefulWidget {
  const MapTransformableReference({super.key});

  @override
  State<MapTransformableReference> createState() => _MapTransformableReferenceState();
}

class _MapTransformableReferenceState extends State<MapTransformableReference> {

  bool _activelyResizing = false;
  bool _activelyDragging = false;

  bool get _activelyTransforming => _activelyResizing || _activelyDragging;

  void onStartTransform() {
    context.read<Reference>().recordTransformStart();
  }

  void onEndTransform() {
    final history = HistoryManager.of(context);
    context.read<Reference>().commitTransform(history);
  }

  void onCancelTransform() {
    context.read<Reference>().cancelTransform();
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final toolSelection = ToolSelection.of(context);
    final history = HistoryManager.of(context);
    final reference = context.watch<Reference>();

    final selected = toolSelection.selectedTool == Tool.references &&
        toolSelection.mapStateOr((ReferencesState state) =>
            state.isReferenceSelected(reference), false);

    final width = reference.imageDimensions.x;
    final height = reference.imageDimensions.y;

    final projectedCenter = camera.getOffset(reference.transform.translation.toPoint());
    final cameraScale     = pow(2, camera.zoom).toDouble() / 32;
    final scaledWidth     = width  * reference.transform.scaleX * cameraScale;
    final scaledHeight    = height * reference.transform.scaleY * cameraScale;

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

    bool invisible = (!selected) && reference.opacity < 0.001;

    if (invisible) {
      return const SizedBox.shrink();
    }

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
          reference.updateTransformIntermediate((transform) {
            transform.translation = camera.getBlockPos(result.rect.center.toPoint()).toOffset();
            transform.scaleX = result.rect.width / width / cameraScale;
            transform.scaleY = result.rect.height / height / cameraScale;
          });
        });
      },

      onResizeStart: (handle, details) {
        bool wasTransforming = _activelyTransforming;
        _activelyResizing = true;
        if (wasTransforming != _activelyTransforming) {
          onStartTransform();
        }
      },
      onResizeEnd: (handle, details) {
        bool wasTransforming = _activelyTransforming;
        _activelyResizing = false;
        if (wasTransforming != _activelyTransforming) {
          onEndTransform();
        }
      },
      onResizeCancel: (handle) {
        bool wasTransforming = _activelyTransforming;
        _activelyResizing = false;
        if (wasTransforming != _activelyTransforming) {
          onCancelTransform();
        }
      },

      onDragStart: (details) {
        bool wasTransforming = _activelyTransforming;
        _activelyDragging = true;
        if (wasTransforming != _activelyTransforming) {
          onStartTransform();
        }
      },
      onDragEnd: (details) {
        bool wasTransforming = _activelyTransforming;
        _activelyDragging = false;
        if (wasTransforming != _activelyTransforming) {
          onEndTransform();
        }
      },
      onDragCancel: () {
        bool wasTransforming = _activelyTransforming;
        _activelyDragging = false;
        if (wasTransforming != _activelyTransforming) {
          onCancelTransform();
        }
      },

      contentBuilder: (context, rect, flip) {
        final img = Image.file(
            reference.image.toFile(),
            width: rect.width,
            height: rect.height,
            fit: BoxFit.fill,
          );
        return GestureDetector(
        onDoubleTap: enabled ? () {
          // Reset aspect ratio
          setState(() {
            final averageScale = (reference.transform.scaleX + reference.transform.scaleY) / 2;
            reference.updateTransformImmediate(history, (transform) {
              transform.scaleX = averageScale;
              transform.scaleY = averageScale;
            });
          });
        } : null,
        child: invisible ? const SizedBox() : Container(
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
          child: Selector(
            selector: (BuildContext context, Reference reference) => (reference.blendMode, reference.opacity),
            builder: (context, data, child) {
              final blendMode = data.$1;
              final opacity = data.$2;
              child ??= const SizedBox();
              return (blendMode == BlendMode.srcOver && !opacity.differs(1.0, 0.001))
                  ? child
                  : BlendMask(
                    blendMode: blendMode,
                    opacity: opacity,
                    child: child
                  );
            },
            child: img,
          ),
        ),
      );
      },
    );
  }
}