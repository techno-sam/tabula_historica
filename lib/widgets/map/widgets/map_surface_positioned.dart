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
import 'package:tabula_historica/widgets/map/flutter_map/map_camera.dart';

class MapSurfacePositioned extends StatelessWidget {
  /// The x-coordinate, in canvas space, of the middle of the widget.
  final double x;
  /// The y-coordinate, in canvas space, of the middle of the widget.
  final double y;

  const MapSurfacePositioned({super.key, required this.x, required this.y});

  Widget get child => Container(
    color: Colors.red,
    child: const Card(
      child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("Lorem ipsum")
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    var projected = camera.getOffset(Point(x, y));

    return Positioned(
      left: projected.x,
      top: projected.y,
      child: child
    );
  }
}