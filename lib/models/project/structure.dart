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
import 'package:tabula_historica/extensions/iterables.dart';
import 'package:uuid/uuid.dart';

import '../../logger.dart';
import '../../widgets/map/flutter_map/map_camera.dart';
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

enum TimePeriod {
  earlyRepublic(Colors.red), // before 300 BCE
  lateRepublic(Colors.orange), // 300 BCE - ?
  rome14CE(Colors.yellow), // 14 CE
  rome117CE(Colors.green), // 117 CE
  // early3rdCentury(Colors.blue), // 200 CE
  ;

  final Color color;

  const TimePeriod(this.color);

  static TimePeriod fromJson(String json) {
    return TimePeriod.values.firstWhere((e) => e.name == json);
  }

  String toJson() {
    return name;
  }

  TimePeriod max(TimePeriod other) {
    return index > other.index ? this : other;
  }
}

enum Width {
  ultraThin(1),
  thin(2),
  semiThin(4),
  normal(8),
  semiThick(16),
  thick(24),
  ultraThick(36),
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
  building(Icons.house_outlined, color: Color(0xFFA50000)),
  river(Icons.water, color: Color(0xFF1976D2)),
  aqueduct(Icons.water_outlined, color: Colors.lightBlue),
  road(Icons.add_road, color: Color(0xFF607D8B)),
  walls(Icons.security_outlined, color: Color(0xFF393939)),
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
  TimePeriod _timePeriod;
  /// the last time period this structure was found in
  TimePeriod _lastTimePeriod;
  Pen _pen;
  List<CompletedStroke> _strokes;
  Stroke? _currentStroke;
  int? _builtYear;
  String? _builtBy;
  int? _destroyedYear;
  String? _destroyedBy;
  Uri? _imageURL;

  String get title => _title;
  String get description => _description ?? "";
  TimePeriod get timePeriod => _timePeriod;
  TimePeriod get lastTimePeriod => _lastTimePeriod;
  Pen get pen => _pen;
  List<Stroke> get strokes => List<Stroke>.unmodifiable(_strokes);
  Stroke? get currentStroke => _currentStroke;
  int? get builtYear => _builtYear;
  String? get builtBy => _builtBy;
  int? get destroyedYear => _destroyedYear;
  String? get destroyedBy => _destroyedBy;
  Uri? get imageURL => _imageURL;

  Rect? _cachedFullBounds;

  Rect get fullBounds {
    if (_cachedFullBounds != null) return _cachedFullBounds!;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final stroke in _strokes) {
      minX = min(minX, stroke._bounds.left);
      minY = min(minY, stroke._bounds.top);
      maxX = max(maxX, stroke._bounds.right);
      maxY = max(maxY, stroke._bounds.bottom);
    }

    _cachedFullBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    return _cachedFullBounds!;
  }

  static final _regexps = [
    RegExp(r"^\d+\.\s*(.*)\s*{.*}$"),
    RegExp(r"^\d+\.\s*(.*)$"),
    RegExp(r"^(.*)\s*{.*}$"),
  ];

  static final _subtitleRegexp = RegExp(r"^(.*)\s*\[(.*)\]$");

  String get titleForDisplay {
    // strip out leading "1." (or other number)
    // also strip out trailing "{...}"
    for (final regexp in _regexps) {
      final match = regexp.firstMatch(_title);
      if (match != null) {
        return match.group(1)!.trim();
      }
    }
    return _title.trim();
  }

  String get titleForDisplayNoSubtitle {
    // strip out trailing " [...]"
    final tfd = titleForDisplay;
    final match = _subtitleRegexp.firstMatch(tfd);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return tfd;
  }

  String? get titleForDisplaySubtitle {
    final tfd = titleForDisplay;
    final match = _subtitleRegexp.firstMatch(tfd);
    if (match != null) {
      return match.group(2)!.trim();
    }
    return null;
  }

  bool get hasInfo => [imageURL, builtYear, builtBy, destroyedYear, destroyedBy].any((e) => e != null);

  Structure({
    String? uuid,
    String? title,
    String? description,
    TimePeriod? timePeriod,
    TimePeriod? lastTimePeriod,
    Pen pen = Pen.building,
    List<CompletedStroke>? strokes
  }):
        _pen = pen,
        _description = description,
        _timePeriod = timePeriod ?? TimePeriod.earlyRepublic,
        _lastTimePeriod = (lastTimePeriod ?? TimePeriod.earlyRepublic).max(timePeriod ?? TimePeriod.earlyRepublic),
        _title = title ?? "Unnamed Structure",
        uuid = uuid ?? const Uuid().v4(),
        _strokes = strokes ?? [];

  factory Structure.fromJson(Map<String, dynamic> json) {
    return Structure(
      uuid: json["uuid"],
      title: json["title"],
      description: json["description"],
      timePeriod: json.mapSingle("timePeriod", (tp) => TimePeriod.fromJson(tp)),
      lastTimePeriod: json.mapSingle("lastTimePeriod", (tp) => TimePeriod.fromJson(tp)),
      pen: Pen.fromJson(json["pen"]),
      strokes: (json["strokes"] as List).map((e) => CompletedStroke.fromJson(e)).toList()
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "uuid": uuid,
      "title": _title,
      "description": _description,
      "timePeriod": _timePeriod.toJson(),
      "lastTimePeriod": _lastTimePeriod.toJson(),
      "pen": _pen.toJson(),
      "strokes": _strokes.map((e) => e.toJson()).toList()
    };
  }

  bool visibleForFilter(TimePeriod filter) {
    return _timePeriod.index <= filter.index && _lastTimePeriod.index >= filter.index;
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

  void setTimePeriod(HistoryManager history, TimePeriod newTimePeriod, {bool skipHistory = false}) {
    if (_timePeriod == newTimePeriod) return;
    if (!skipHistory) {
      history.record(ModifyStructureTimePeriodHistoryEntry(uuid, _timePeriod, newTimePeriod));
    }
    _timePeriod = newTimePeriod;
    _lastTimePeriod = _lastTimePeriod.max(newTimePeriod);
    logger.d("Changed time period of $this to $newTimePeriod");
    markDirty();
  }

  void setLastTimePeriod(HistoryManager history, TimePeriod newTimePeriod, {bool skipHistory = false}) {
    newTimePeriod = newTimePeriod.max(_timePeriod);
    if (_lastTimePeriod == newTimePeriod) return;
    if (!skipHistory) {
      history.record(ModifyStructureLastTimePeriodHistoryEntry(uuid, _lastTimePeriod, newTimePeriod));
    }
    _lastTimePeriod = newTimePeriod;
    logger.d("Changed last time period of $this to $newTimePeriod");
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

  void setBuiltYear(HistoryManager history, int? newBuiltYear, {bool skipHistory = false}) {
    if (newBuiltYear == 0) newBuiltYear = null;
    if (_builtYear == newBuiltYear) return;
    if (!skipHistory) {
      history.record(ModifyStructureBuiltYearHistoryEntry(uuid, _builtYear, newBuiltYear));
    }
    _builtYear = newBuiltYear;
    logger.d("Changed built year of $this to $newBuiltYear");
    markDirty();
  }

  void setBuiltBy(HistoryManager history, String? newBuiltBy, {bool skipHistory = false}) {
    if (_builtBy == newBuiltBy) return;
    if (!skipHistory) {
      history.record(ModifyStructureBuiltByHistoryEntry(uuid, _builtBy, newBuiltBy));
    }
    _builtBy = newBuiltBy;
    logger.d("Changed built by of $this to $newBuiltBy");
    markDirty();
  }

  void setDestroyedYear(HistoryManager history, int? newDestroyedYear, {bool skipHistory = false}) {
    if (newDestroyedYear == 0) newDestroyedYear = null;
    if (_destroyedYear == newDestroyedYear) return;
    if (!skipHistory) {
      history.record(ModifyStructureDestroyedYearHistoryEntry(uuid, _destroyedYear, newDestroyedYear));
    }
    _destroyedYear = newDestroyedYear;
    logger.d("Changed destroyed year of $this to $newDestroyedYear");
    markDirty();
  }

  void setDestroyedBy(HistoryManager history, String? newDestroyedBy, {bool skipHistory = false}) {
    if (_destroyedBy == newDestroyedBy) return;
    if (!skipHistory) {
      history.record(ModifyStructureDestroyedByHistoryEntry(uuid, _destroyedBy, newDestroyedBy));
    }
    _destroyedBy = newDestroyedBy;
    logger.d("Changed destroyed by of $this to $newDestroyedBy");
    markDirty();
  }

  void setImageURL(HistoryManager history, Uri? newImageURL, {bool skipHistory = false}) {
    if (_imageURL == newImageURL) return;
    if (!skipHistory) {
      history.record(ModifyStructureImageURLHistoryEntry(uuid, _imageURL, newImageURL));
    }
    _imageURL = newImageURL;
    logger.d("Changed image URL of $this to $newImageURL");
    markDirty();
  }

  void startStroke(HistoryManager history, Width width, Offset start) {
    if (_currentStroke != null) {
      _strokes.add(CompletedStroke.from(_currentStroke!));
      _cachedFullBounds = null;
    }
    _currentStroke = Stroke(width: width, points: [start]);
    markDirty();
  }

  void updateStroke(Offset point) {
    if (_currentStroke == null) return;
    _currentStroke!.points.add(point);
    markDirty();
  }

  void endStroke(HistoryManager history) {
    if (_currentStroke == null) return;
    _strokes.add(CompletedStroke.from(_currentStroke!));
    _cachedFullBounds = null;
    _currentStroke = null;
    history.record(AddStrokeToStructureHistoryEntry(uuid));
    markDirty();
  }

  void $forHistory$restoreStroke(Stroke stroke) {
    _strokes.add(CompletedStroke.from(stroke));
    _cachedFullBounds = null;
    markDirty();
  }

  Stroke? $forHistory$removeStroke() {
    final ret = _strokes.removeLast();
    _cachedFullBounds = null;
    markDirty();
    return ret;
  }

  @override
  void markDirty() {
    super.markDirty();
    notifyListeners();
  }

  @override
  String toString() {
    return "Structure(uuid: $uuid, title: $_title, description: $_description, pen: $_pen, strokes: ${_strokes.length})";
  }
}