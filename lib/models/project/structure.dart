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

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:tabula_historica/models/project/history_manager.dart';
import 'package:uuid/uuid.dart';

import '../../extensions/color_manipulation.dart';
import '../../logger.dart';
import 'foundation/needs_save.dart';

/*final StrokeOptions _defaultStrokeOptions = StrokeOptions(
  isComplete: true,
  streamline: 0.15,
  smoothing: 0.3,
  thinning: 0.6,
  size: Width.normal.value,
);*/

enum Width {
  thin(2),
  semiThin(4),
  normal(8),
  semiThick(16),
  thick(32),
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
  building(),
  aqueduct(color: Colors.lightBlue),
  ;
  final Color color;
  final double _streamline;
  final double _smoothing;
  final double _thinning;

  const Pen({
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

class Structure with NeedsSave, ChangeNotifier {
  final String uuid;
  String _title;
  String? _description;
  Pen _pen;
  List<Stroke> _strokes;
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
    List<Stroke>? strokes
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
      strokes: (json["strokes"] as List).map((e) => Stroke.fromJson(e)).toList()
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
      _strokes.add(_currentStroke!);
    }
    _currentStroke = Stroke(width: width, points: [start]);
    markDirty();
  }

  void addPoint(HistoryManager history, Offset point) {
    if (_currentStroke == null) return;
    _currentStroke!.points.add(point);
    markDirty();
  }

  void endStroke(HistoryManager history) {
    if (_currentStroke == null) return;
    _strokes.add(_currentStroke!);
    _currentStroke = null;
    markDirty();
  }

  @override
  void markDirty() {
    super.markDirty();
    notifyListeners();
  }
}