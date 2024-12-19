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
import 'package:uuid/uuid.dart';

import '../../logger.dart';
import 'foundation/needs_save.dart';
import 'foundation/project_path.dart';
import '../transform.dart';
import 'history_manager.dart';
import 'loading_context.dart';

class Reference with NeedsSave, ChangeNotifier {
  final String _uuid;
  ProjectPath image;
  Point<int> imageDimensions;
  String title;
  double opacity;
  BlendMode blendMode;
  final Transform2D _transform;
  late final Transform2DView _transformView = Transform2DView(_transform);
  String get uuid => _uuid;

  Reference({
    String? uuid,
    required this.image,
    required this.imageDimensions,
    String? title,
    this.opacity = 1.0,
    this.blendMode = BlendMode.srcOver,
    Transform2D? transform
  })
      : _uuid = uuid ?? const Uuid().v4(),
        title = title ?? "Unnamed Reference",
        _transform = transform ?? Transform2D();

  Transform2DView get transform => _transformView;

  factory Reference.fromJson(LoadingContext ctx, Map<String, dynamic> json) {
    return Reference(
        uuid: json["uuid"],
        image: ProjectPath(projectRoot: ctx.projectRoot, path: json["image"]["path"]),
        imageDimensions: Point<int>(json["image"]["width"], json["image"]["height"]),
        title: json["title"] ?? "Unnamed Reference",
        opacity: (json["opacity"] as num?)?.toDouble() ?? 1.0,
        blendMode: BlendMode.values.where((e) => e.name == json["blendMode"]).firstOrNull ?? BlendMode.srcOver,
        transform: Transform2D.fromJson(json["transform"]  ?? {})
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "uuid": _uuid,
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

  Transform2D? _transformStart;
  void recordTransformStart() {
    _transformStart = _transform.clone();
    logger.d("Recorded transform start for $this");
  }

  void updateTransformIntermediate(void Function(Transform2D) updater, {bool discardStart = false}) {
    if (discardStart) {
      _transformStart = null;
    }
    updater(_transform);
    markDirty();
    logger.t("Updated intermediate transform of $this");
  }

  void cancelTransform() {
    if (_transformStart == null) return;
    _transform.copyFrom(_transformStart!);
    _transformStart = null;
    markDirty();
    logger.d("Cancelled transform of $this");
  }

  void commitTransform(HistoryManager history) {
    if (_transformStart == null) return;
    if (_transform != _transformStart) {
      history.record(ModifyReferenceTransformHistoryEntry(uuid, _transformStart!, _transform));
    }
    _transformStart = null;
    logger.d("Committed transform of $this");
  }

  void updateTransformImmediate(HistoryManager history, void Function(Transform2D) updater) {
    recordTransformStart();
    updateTransformIntermediate(updater);
    commitTransform(history);
  }

  void setTitle(HistoryManager history, String newTitle, {bool skipHistory = false}) {
    if (title == newTitle) return;
    if (!skipHistory) {
      history.record(ModifyReferenceTitleHistoryEntry(uuid, title, newTitle));
    }
    title = newTitle;
    logger.d("Set title of $this to $newTitle");
    markDirty();
  }

  void setBlendMode(HistoryManager history, BlendMode newBlendMode, {bool skipHistory = false}) {
    if (blendMode == newBlendMode) return;
    if (!skipHistory) {
      history.record(ModifyReferenceBlendModeHistoryEntry(uuid, blendMode, newBlendMode));
    }
    blendMode = newBlendMode;
    logger.d("Set blend mode of $this to $newBlendMode");
    markDirty();
  }

  double? _opacityStart;
  void recordOpacityStart() {
    _opacityStart = opacity;
    logger.d("Recorded opacity change start for $this");
  }

  void updateOpacityIntermediate(double newOpacity, {bool discardStart = false}) {
    if (discardStart) {
      _opacityStart = null;
    }
    opacity = newOpacity;
    markDirty();
    logger.t("Updated intermediate opacity of $this");
  }

  void cancelOpacity() {
    if (_opacityStart == null) return;
    opacity = _opacityStart!;
    _opacityStart = null;
    markDirty();
    logger.d("Cancelled opacity change of $this");
  }

  void commitOpacity(HistoryManager history) {
    if (_opacityStart == null) return;
    if (opacity != _opacityStart) {
      history.record(ModifyReferenceOpacityHistoryEntry(uuid, _opacityStart!, opacity));
    }
    _opacityStart = null;
    logger.d("Committed opacity change of $this");
  }

  @override
  void markDirty() {
    super.markDirty();
    notifyListeners();
  }

  @override
  String toString() {
    return "Reference($title @ ${image.path}){$uuid}";
  }
}
