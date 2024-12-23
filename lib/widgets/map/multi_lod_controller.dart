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

part of 'multi_lod.dart';

class _MapController extends SingleChildStatelessWidget {
  final int tileSize;

  const _MapController({
    // ignore: unused_element
    super.key,
    super.child,
    // ignore: unused_element
    this.tileSize = 256,
  });

  /// Applies a [deltaScale] zoom change to the [camera], centered around the given screen-space [center].
  void _applyScaleChange(double deltaScale, Offset center, MapCamera camera) {
    double centerX = camera.blockPosCenter.x;
    double centerZ = camera.blockPosCenter.y;
    double scale = camera.zoom;
    double uiInteractionScale = pow(2, scale).toDouble();

    double xUnderCursor = centerX + (center.dx - camera.size.width / 2) /
        (uiInteractionScale / 32);
    double zUnderCursor = centerZ + (center.dy - camera.size.height / 2) /
        (uiInteractionScale / 32);

    scale += deltaScale;
    scale = scale.clamp(camera.minZoom, camera.maxZoom);

    uiInteractionScale = pow(2, scale).toDouble();

    centerX = xUnderCursor - (center.dx - camera.size.width / 2) /
        (uiInteractionScale / 32);
    centerZ = zUnderCursor - (center.dy - camera.size.height / 2) /
        (uiInteractionScale / 32);

    camera.asBatchOperation(() {
      camera.blockPosCenter = Point(centerX, centerZ);
      camera.zoom = scale;
    });
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    final camera = MapCamera.of(context, listen: false);
    final toolSelection = ToolSelection.maybeOf(context, listen: false);

    final List<Offset> communicatedCenter = [const Offset(0, 0)];

    return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (details) {
          logger.t("Clicked block pos ${camera.getBlockPos(
              details.localPosition.toPoint())}");
        },
        onPointerHover: (details) {
          communicatedCenter[0] = details.localPosition;
        },
        onPointerMove: (details) {
          communicatedCenter[0] = details.localPosition;
          if (details.down && ((toolSelection?.selectedTool ?? Tool.pan) == Tool.pan ||
              details.matches(primary: false, secondary: true))) {
            double unadjustedScale = pow(2, camera.zoom).toDouble();
            Point<double> offset = Point(
                details.delta.dx / unadjustedScale,
                details.delta.dy / unadjustedScale
            );
            camera.blockPosCenter = camera.blockPosCenter - offset * 32;
          }
        },
        onPointerSignal: (details) {
          if (details is PointerScrollEvent) {
            _applyScaleChange(
                -details.scrollDelta.dy / 150, details.localPosition, camera);
          }
        },
        onPointerPanZoomUpdate: (details) {
          _applyScaleChange(
              details.panDelta.dy / 100, details.localPosition, camera);
        },
        child: child
    );
  }
}
