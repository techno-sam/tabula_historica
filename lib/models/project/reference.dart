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

import 'foundation/project_path.dart';
import '../transform.dart';
import 'loading_context.dart';

class Reference {
  ProjectPath image;
  Point<int> imageDimensions;
  String title;
  double opacity;
  BlendMode blendMode;
  final Transform2D _transform;
  late final Transform2DView _transformView = Transform2DView(_transform);

  Reference({
    required this.image,
    required this.imageDimensions,
    String? title,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
    Transform2D? transform
  })
      : title = title ?? "Unnamed Reference",
        _transform = transform ?? Transform2D();

  Transform2DView get transform => _transformView;

  factory Reference.fromJson(LoadingContext ctx, Map<String, dynamic> json) {
    return Reference(
        image: ProjectPath(projectRoot: ctx.projectRoot, path: json["image"]["path"]),
        imageDimensions: Point<int>(json["image"]["width"], json["image"]["height"]),
        title: json["title"],
        opacity: json["opacity"],
        blendMode: BlendMode.values.where((e) => e.name == json["blendMode"]).first,
        transform: Transform2D.fromJson(json["transform"])
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "image": {
        "path": image.path,
        "width": imageDimensions.x,
        "height": imageDimensions.y
      },
      "title": title,
      "opacity": opacity,
      "blendMode": blendMode.name,
      "transform": _transform.toJson()
    };
  }

  /// Projects a point from reference space to canvas space
  Point<double> project(Point<double> point) {
    // reference space is -1 to 1, where (-1, -1) is top-left and (1, 1) is bottom-right
    // canvas space is arbitrarily large
    // This image's dimensions in canvas space are (imageDimensions.x * transform.scaleX, imageDimensions.y * transform.scaleY)
    // This image's position in canvas space is (transform.translationX, transform.translationY)
    // This image's rotation in canvas space is transform.rotation

    // First, scale the point to the image's dimensions
    Point<double> scaled = Point<double>(
      point.x * transform.scaleX * imageDimensions.x,
      point.y * transform.scaleY * imageDimensions.y
    );

    // Then, rotate the point around the origin
    double angle = transform.rotation;
    double cosA = cos(angle);
    double sinA = sin(angle);
    Point<double> rotated = Point<double>(
      scaled.x * cosA - scaled.y * sinA,
      scaled.x * sinA + scaled.y * cosA
    );

    // Finally, translate the point to the image's position
    Point<double> translated = Point<double>(
      rotated.x + transform.translationX,
      rotated.y + transform.translationY
    );

    return translated;
  }

  /// Projects a point from canvas space to reference space
  Point<double> reverseProject(Point<double> point) {
    // First, translate the point to the image's position
    Point<double> translated = Point<double>(
      point.x - transform.translationX,
      point.y - transform.translationY
    );

    // Then, rotate the point around the origin
    double angle = -transform.rotation;
    double cosA = cos(angle);
    double sinA = sin(angle);
    Point<double> rotated = Point<double>(
      translated.x * cosA - translated.y * sinA,
      translated.x * sinA + translated.y * cosA
    );

    // Finally, scale the point to the image's dimensions
    Point<double> scaled = Point<double>(
      rotated.x / (transform.scaleX * imageDimensions.x),
      rotated.y / (transform.scaleY * imageDimensions.y)
    );

    return scaled;
  }
}
