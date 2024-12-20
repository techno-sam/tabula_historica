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
import 'package:perfect_freehand/perfect_freehand.dart' hide Point;
import 'package:uuid/uuid.dart';

import '../../logger.dart';
import '../../widgets/map/flutter_map/map_camera.dart';
import '../../widgets/map/flutter_map/extensions/point.dart';
import 'foundation/needs_save.dart';
import 'history_manager.dart';

/*final StrokeOptions _defaultStrokeOptions = StrokeOptions(
  isComplete: true,
  streamline: 0.15,
  smoothing: 0.3,
  thinning: 0.6,
  size: Width.normal.value,
);*/

const int structureDetailMultiplier = 2;

enum Width {
  thin(2),
  semiThin(4),
  normal(8),
  semiThick(16),
  thick(24),
  ;
  final double value;

  const Width(this.value);

  static Width fromJson(String json) {
    return Width.values.firstWhere((e) => e.name == json);
  }

  String toJson() {
    return name;
  }
}

enum Pen {
  building(Icons.house_outlined),
  aqueduct(Icons.water_outlined, color: Colors.lightBlue),
  ;
  final IconData icon;
  final Color color;
  final double _streamline;
  final double _smoothing;
  final double _thinning;

  const Pen(this.icon, {
    this.color = Colors.black,
    double streamline = 0.15,
    double smoothing = 0.3,
    double thinning = 0.6,
  }):
        _thinning = thinning,
        _smoothing = smoothing,
        _streamline = streamline;

  StrokeOptions getOptions(bool isComplete, {Width width = Width.normal}) {
    return StrokeOptions(
      isComplete: isComplete,
      streamline: _streamline,
      smoothing: _smoothing,
      thinning: _thinning,
      size: width.value
    );
  }

  static Pen fromJson(String json) {
    return Pen.values.firstWhere((e) => e.name == json);
  }

  String toJson() {
    return name;
  }
}

class Stroke {
  final Width width;
  final List<Offset> points;

  Stroke({
    required this.width,
    required this.points
  });

  factory Stroke.fromJson(Map<String, dynamic> json) {
    return Stroke(
      width: Width.fromJson(json["width"]),
      points: (json["points"] as List).map((e) => Offset(e[0], e[1])).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "width": width.toJson(),
      "points": points.map((e) => [e.dx, e.dy]).toList(),
    };
  }
}

class CompletedStroke extends Stroke {
  late final Rect _bounds;
  List<PointVector>? _cachedBase;
  int? _outlineStrokeOptionsHash;
  List<Offset>? _cachedUntransformedOutline;

  CompletedStroke({
    required super.width,
    required List<Offset> points,
  }) : super(points: List.unmodifiable(points)) {
    if (points.isEmpty) {
      _bounds = Rect.zero;
    } else {
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = double.negativeInfinity;
      double maxY = double.negativeInfinity;

      for (final point in points) {
        minX = min(minX, point.dx);
        minY = min(minY, point.dy);
        maxX = max(maxX, point.dx);
        maxY = max(maxY, point.dy);
      }

      _bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    }
  }

  CompletedStroke.from(Stroke stroke):
        this(width: stroke.width, points: List.unmodifiable(stroke.points));

  factory CompletedStroke.fromJson(Map<String, dynamic> json) {
    return CompletedStroke.from(Stroke.fromJson(json));
  }

  bool visible(MapCamera camera) {
    return camera.getOffsetRect(_bounds)
        .overlaps(Rect.fromLTWH(0, 0, camera.size.width, camera.size.height));
  }

  void clearCache() {
    _cachedBase = null;
    _cachedUntransformedOutline = null;
  }

  List<PointVector> _getBase() {
    if (_cachedBase != null) return _cachedBase!;

    _cachedBase = points
        .map((p) => p * structureDetailMultiplier.toDouble())
        .map((p) => PointVector(p.dx, p.dy))
        .toList();

    return _cachedBase!;
  }

  List<Offset> getUntransformedOutline(StrokeOptions options) {
    if (_outlineStrokeOptionsHash != options.hashCode) {
      _outlineStrokeOptionsHash = options.hashCode;
      _cachedUntransformedOutline = null;
    }

    if (_cachedUntransformedOutline != null) return _cachedUntransformedOutline!;

    final outline = getStroke(_getBase(), options: options);

    final invDetail = 1 / structureDetailMultiplier.toDouble();
    _cachedUntransformedOutline = outline
        .map((e) => e.scale(invDetail, invDetail))
        .toList();

    return _cachedUntransformedOutline!;
  }
}

class Structure with NeedsSave, ChangeNotifier {
  final String uuid;
  String _title;
  String? _description;
  Pen _pen;
  List<CompletedStroke> _strokes;
  Stroke? _currentStroke;

  String get title => _title;
  String get description => _description ?? "";
  Pen get pen => _pen;
  List<Stroke> get strokes => List<Stroke>.unmodifiable(_strokes);
  Stroke? get currentStroke => _currentStroke;

  Structure({
    String? uuid,
    String? title,
    String? description,
    Pen pen = Pen.building,
    List<CompletedStroke>? strokes
  }):
        _pen = pen,
        _description = description,
        _title = title ?? "Unnamed Structure",
        uuid = uuid ?? const Uuid().v4(),
        _strokes = strokes ?? [];

  factory Structure.fromJson(Map<String, dynamic> json) {
    return Structure(
      uuid: json["uuid"],
      title: json["title"],
      description: json["description"],
      pen: Pen.fromJson(json["pen"]),
      strokes: (json["strokes"] as List).map((e) => CompletedStroke.fromJson(e)).toList()
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "uuid": uuid,
      "title": _title,
      "description": _description,
      "pen": _pen.toJson(),
      "strokes": _strokes.map((e) => e.toJson()).toList()
    };
  }

  void setTitle(HistoryManager history, String newTitle, {bool skipHistory = false}) {
    if (_title == newTitle) return;
    if (!skipHistory) {
      history.record(ModifyStructureTitleHistoryEntry(uuid, _title, newTitle));
    }
    _title = newTitle;
    logger.d("Changed title of $this to $newTitle");
    markDirty();
  }

  void setDescription(HistoryManager history, String? newDescription, {bool skipHistory = false}) {
    if (_description == newDescription) return;
    if (!skipHistory) {
      history.record(ModifyStructureDescriptionHistoryEntry(uuid, _description, newDescription));
    }
    _description = newDescription;
    logger.d("Changed description of $this to $newDescription");
    markDirty();
  }

  void setPen(HistoryManager history, Pen newPen, {bool skipHistory = false}) {
    if (_pen == newPen) return;
    if (!skipHistory) {
      history.record(ModifyStructurePenHistoryEntry(uuid, _pen, newPen));
    }
    _pen = newPen;
    logger.d("Changed pen of $this to $newPen");
    markDirty();
  }

  void startStroke(HistoryManager history, Width width, Offset start) {
    if (_currentStroke != null) {
      _strokes.add(CompletedStroke.from(_currentStroke!));
    }
    _currentStroke = Stroke(width: width, points: [start]);
    markDirty();
  }

  void updateStroke(HistoryManager history, Offset point) {
    if (_currentStroke == null) return;
    _currentStroke!.points.add(point);
    markDirty();
  }

  void endStroke(HistoryManager history) {
    if (_currentStroke == null) return;
    _strokes.add(CompletedStroke.from(_currentStroke!));
    _currentStroke = null;
    markDirty();
  }

  @override
  void markDirty() {
    super.markDirty();
    notifyListeners();
  }
}