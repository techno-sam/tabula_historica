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

import 'package:flutter/material.dart';

import '../flutter_map/map_camera.dart';

class MapSurfacePositioned extends StatelessWidget {
  /// The x-coordinate, in canvas space, of the middle of the widget.
  final double x;
  /// The y-coordinate, in canvas space, of the middle of the widget.
  final double y;
  /// The size in meters of a single pixel in widget space.
  final double baseScale;
  /// The widget to position.
  final Widget child;

  const MapSurfacePositioned({super.key, required this.x, required this.y, required this.baseScale, required this.child});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    final projected = camera.getOffset(Point(x, y));
    final scale = baseScale * pow(2, camera.zoom).toDouble() / 32;

    const double halfSize = 50;
    final double scaledHalfSize = halfSize * scale;

    return Positioned(
      left: projected.x - scaledHalfSize,
      top: projected.y - scaledHalfSize,
      child: Container(
        color: Colors.lightBlueAccent.withOpacity(0.2),
        child: SizedBox(
          width: scaledHalfSize*2,
          height: scaledHalfSize*2,
          child: Align(
            alignment: Alignment.center,
            child: OverflowBox(
              maxHeight: double.infinity,
              maxWidth: double.infinity,
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  //width: halfSize*2,
                  //height: halfSize*2,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      )
    );
  }
}

class DebugMapSurfacePositioned extends StatelessWidget {
  /// The x-coordinate, in canvas space, of the middle of the widget.
  final double x;

  /// The y-coordinate, in canvas space, of the middle of the widget.
  final double y;

  /// The size in meters of a single pixel in widget space.
  final double baseScale;

  /// Which debug widget to display
  final bool which;

  const DebugMapSurfacePositioned(
      {super.key, required this.x, required this.y, required this.baseScale, required this.which});

  @override
  Widget build(BuildContext context) {
    return MapSurfacePositioned(
      x: x,
      y: y,
      baseScale: baseScale,
      child: which
          ? SizedBox(
              width: 2,
              height: 2,
              child: Container(
                color: Colors.greenAccent.withOpacity(0.2),
                child: const Icon(Icons.add, size: 1,),
              ),
            )
          : Container(
              color: Colors.red,
              child: const Card(
                child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Lorem ipsum")
                ),
              ),
            ),
    );
  }
}