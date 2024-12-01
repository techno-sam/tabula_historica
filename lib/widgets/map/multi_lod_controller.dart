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
 */

part of 'multi_lod.dart';

class _MapController extends SingleChildStatelessWidget {
  final int tileSize;

  const _MapController({
    super.key,
    super.child,
    this.tileSize = 256,
  });

  /// Applies a [deltaScale] zoom change to the [camera], centered around the given screen-space [center].
  void _applyScaleChange(double deltaScale, Offset center, MapCamera camera) {

    if (_debugPadding != null) {
      center = Offset(center.dx - _debugPadding!, center.dy - _debugPadding!);
    }

    double centerX = camera.blockPosCenter.x;
    double centerZ = camera.blockPosCenter.y;
    double scale = camera.zoom;
    double uiInteractionScale = pow(2, scale).toDouble();

    double xUnderCursor = centerX + (center.dx - camera.size.width / 2) /
        (tileSize * uiInteractionScale);
    double zUnderCursor = centerZ + (center.dy - camera.size.height / 2) /
        (tileSize * uiInteractionScale);

    scale += deltaScale;
    scale = scale.clamp(log2(1 / 8), log2(128));

    uiInteractionScale = pow(2, scale).toDouble();

    centerX = xUnderCursor - (center.dx - camera.size.width / 2) /
        (tileSize * uiInteractionScale);
    centerZ = zUnderCursor - (center.dy - camera.size.height / 2) /
        (tileSize * uiInteractionScale);

    camera.asBatchOperation(() {
      camera.blockPosCenter = Point(centerX, centerZ);
      camera.zoom = scale;
    });
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    final camera = MapCamera.of(context, listen: false);

    final List<Offset> communicatedCenter = [const Offset(0, 0)];

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey.keyLabel == "D") {
          // zoom to max zoom
          _applyScaleChange(1000, communicatedCenter[0], camera);
        }
      },
      child: Listener(
          onPointerHover: (details) {
            communicatedCenter[0] = details.localPosition;
          },
          onPointerMove: (details) {
            communicatedCenter[0] = details.localPosition;
            if (details.down) {
              double unadjustedScale = pow(2, camera.zoom).toDouble();
              Point<double> offset = Point(
                  details.delta.dx / (tileSize * unadjustedScale),
                  details.delta.dy / (tileSize * unadjustedScale)
              );
              camera.blockPosCenter = camera.blockPosCenter - offset;
            }
          },
          onPointerSignal: (details) {
            if (details is PointerScrollEvent) {
              _applyScaleChange(-details.scrollDelta.dy / 150, details.position, camera); // fixme should this use localPosition?
            }
          },
          onPointerPanZoomUpdate: (details) {
            _applyScaleChange(details.panDelta.dy / 100, details.localPosition, camera);
          },
          child: child
      ),
    );
  }
}
