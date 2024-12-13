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

import 'dart:ui';

abstract class Transform2DView {
  factory Transform2DView(Transform2DView transform) =>
      _Transform2DViewImpl(transform);

  double get translationX;

  double get translationY;

  double get scaleX;

  double get scaleY;

  /// Rotation in radians, positive is counter-clockwise
  double get rotation;

  Map<String, dynamic> toJson();
}

class Transform2D implements Transform2DView {
  @override
  double translationX;
  @override
  double translationY;

  @override
  double scaleX;
  @override
  double scaleY;

  @override
  double rotation;

  Transform2D({this.translationX = 0.0,
    this.translationY = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotation = 0.0});

  factory Transform2D.fromJson(Map<String, dynamic> json) {
    return Transform2D(
        translationX: (json["translation"]["x"] as num).toDouble(),
        translationY: (json["translation"]["y"] as num).toDouble(),
        scaleX: (json["scale"]["x"] as num).toDouble(),
        scaleY: (json["scale"]["y"] as num).toDouble(),
        rotation: (json["rotation"] as num).toDouble());
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "translation": {"x": translationX, "y": translationY},
      "scale": {"x": scaleX, "y": scaleY},
      "rotation": rotation
    };
  }
}

class _Transform2DViewImpl implements Transform2DView {
  final Transform2DView _wrapped;

  _Transform2DViewImpl(this._wrapped);

  @override
  double get translationX => _wrapped.translationX;

  @override
  double get translationY => _wrapped.translationY;

  @override
  double get scaleX => _wrapped.scaleX;

  @override
  double get scaleY => _wrapped.scaleY;

  @override
  double get rotation => _wrapped.rotation;

  @override
  Map<String, dynamic> toJson() => _wrapped.toJson();
}

extension ViewConvenienceExtension on Transform2DView {
  Offset get translation => Offset(translationX, translationY);
}

extension ConvenienceExtension on Transform2D {
  Offset get translation => Offset(translationX, translationY);

  set translation(Offset value) {
    translationX = value.dx;
    translationY = value.dy;
  }
}
