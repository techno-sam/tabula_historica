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

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../../extensions/iterables.dart';
import '../../extensions/directory.dart';
import '../../logger.dart';
import '../../util/string.dart';
import 'foundation/needs_save.dart';
import 'foundation/project_path.dart';
import 'history_manager.dart';
import 'loading_context.dart';
import 'reference.dart';
import 'structure.dart';

abstract class ReorderableListModel<T extends Object> extends ChangeNotifier implements NeedsSave {
  final List<T> __objects;
  bool __extraNeedsSave = false;

  ReorderableListModel([List<T>? objects]): __objects = objects ?? [];

  Iterable<T> get _objects => __objects;
  Iterable<T> get _objectsReversed => __objects.reversed;

  get length => __objects.length;

  T operator[](int index) => __objects[index];

  void add(T object, {int? index}) {
    __objects.insert(index ?? 0, object);
    markDirty();
    notifyListeners();
  }

  int? remove(T object) {
    int? idx = __objects.nullableIndexOf(object);
    if (idx != null) {
      __objects.removeAt(idx);
      markDirty();
      notifyListeners();
    }
    return idx;
  }

  String _getUuid(T object);
  void _recordReorder(HistoryManager history, T object, int from, int actualTo);

  void reorder(HistoryManager history, int from, int to, {bool skipHistory = false, String? uuid}) {
    if (from < 0 || from >= __objects.length) {
      throw ArgumentError.value(from, "from", "invalid index");
    }
    if (to < 0) {
      throw ArgumentError.value(to, "to", "invalid index");
    }
    to = min(to, __objects.length);

    if (from == to) {
      return;
    }

    final value = __objects.removeAt(from);
    if (uuid != null && _getUuid(value) != uuid) {
      __objects.insert(from, value);
      throw ArgumentError.value(uuid, "uuid", "UUID mismatch, got ${_getUuid(value)}");
    }
    final int actualTo = to;
    if (from < to - 1) { // account for the fact that we just shifted every item
      to--;
    }
    __objects.insert(to, value);

    if (!skipHistory) {
      _recordReorder(history, value, from, actualTo);
    }

    markDirty();
    notifyListeners();
  }

  @override
  void markClean() {
    __extraNeedsSave = false;
    for (var e in __objects) {
      if (e is NeedsSave) {
        e.markClean();
      }
    }
  }

  @override
  void markDirty() {
    __extraNeedsSave = true;
  }

  @override
  bool get needsSave => __extraNeedsSave || __objects.any((e) => e is NeedsSave && e.needsSave);

  @override
  void dispose() {
    for (var e in __objects) {
      if (e is ChangeNotifier) {
        e.dispose();
      }
    }
    super.dispose();
  }

  static ReferenceList of(BuildContext context, {bool listen = true}) {
    return Provider.of(context, listen: listen);
  }
}

class ReferenceList extends ReorderableListModel<Reference> {
  ReferenceList([super.references]);

  Iterable<Reference> get references => _objects;
  Iterable<Reference> get referencesReversed => _objectsReversed;

  @pragma('vm:prefer-inline')
  @override
  String _getUuid(Reference object) => object.uuid;

  @override
  void _recordReorder(HistoryManager history, Reference object, int from, int actualTo) {
    history.record(ReorderReferenceHistoryEntry(object.uuid, from, actualTo));
  }

  static ReferenceList of(BuildContext context, {bool listen = true}) {
    return Provider.of(context, listen: listen);
  }
}

class StructureList extends ReorderableListModel<Structure> {
  StructureList([super.structures]);

  Iterable<Structure> get structures => _objects;
  Iterable<Structure> get structuresReversed => _objectsReversed;

  @pragma('vm:prefer-inline')
  @override
  String _getUuid(Structure object) => object.uuid;

  @override
  void _recordReorder(HistoryManager history, Structure object, int from, int actualTo) {
    history.record(ReorderStructureHistoryEntry(object.uuid, from, actualTo));
  }

  static StructureList of(BuildContext context, {bool listen = true}) {
    return Provider.of(context, listen: listen);
  }
}

class Project implements NeedsSave {
  final Directory root;
  final bool fromStaticAsset;
  final ReferenceList references;
  final StructureList structures;
  late final HistoryManager historyManager;
  bool _extraNeedsSave = false;

  LoadingContext get loadingContext => LoadingContext(projectRoot: root, getProject: () => this);

  Project._({
    required this.root,
    List<Reference>? references,
    List<Structure>? structures,
    HistoryManager? historyManager,
    required this.fromStaticAsset
  }): references = ReferenceList(references), structures = StructureList(structures) {
    this.historyManager = historyManager ?? HistoryManager(getProject: () => this);
  }

  factory Project.load(Directory root) {
    logger.d("Loading project from $root");
    File file = File("${root.path}/project.json");
    if (!file.existsSync()) {
      return Project._(root: root, fromStaticAsset: false);
    }

    return Project._fromJson(root, jsonDecode(file.readAsStringSync()), false);
  }

  static Future<Project> loadFromAssets() async {
    return Project._fromJson(Directory(""), jsonDecode(await rootBundle.loadString("static/static-project.json")), true);
  }

  factory Project._fromJson(Directory root, Map<String, dynamic> json, bool fromStaticAsset) {
    final tmp = <Project?>[null];
    LoadingContext ctx = LoadingContext(
      getProject: () => tmp[0]!,
      projectRoot: root,
    );

    final project = Project._(
      root: root,
      references: json.mapSingle("references", (refs) => (refs as List).map((e) => Reference.fromJson(ctx, e)).toList()),
      structures: json.mapSingle("structures", (structs) => (structs as List).map((e) => Structure.fromJson(e)).toList()),
      historyManager: json.mapSingle("historyManager", (hm) => HistoryManager.fromJson(ctx, hm)),
      fromStaticAsset: fromStaticAsset
    );
    tmp[0] = project;
    return project;
  }

  Map<String, dynamic> toJson() {
    return {
      "references": references.references.map((e) => e.toJson()).toList(),
      "structures": structures.structures.map((e) => e.toJson()).toList(),
      "historyManager": historyManager.toJson()
    };
  }

  void dispose() {
    references.dispose();
    structures.dispose();
    historyManager.dispose();
    logger.d("Disposed $this");
  }

  Future<void> save() async {
    if (fromStaticAsset) {
      throw StateError("Cannot save a project loaded from assets");
    }
    File file = File("${root.path}/project.json");
    await file.writeAsString(prettyEncoder.convert(toJson()));
    markClean();
  }

  Future<Reference> createReference(File sourceImage, Point<int> dimensions, String? title) async {
    String name = "${slug(6)}-${sourceImage.path.split("/").last}";
    Directory $references = root.resolve("references");
    await $references.create(recursive: true);

    File destImage = $references.resolveFile(name);
    await sourceImage.copy(destImage.path);

    var reference = Reference(
      image: ProjectPath(projectRoot: root, path: "references/$name"),
      imageDimensions: dimensions,
      title: title
    );
    references.add(reference);

    historyManager.record(AddReferenceHistoryEntry(reference));

    return reference;
  }

  Future<void> removeReference(Reference reference) async {
    final idx = references.remove(reference);
    if (idx == null) {
      throw ArgumentError("Reference not found");
    }
    await moveImageToHistoricalStorage(this, reference);
    historyManager.record(RemoveReferenceHistoryEntry(reference, idx));
  }

  Reference? getReference(String uuid) {
    return references.references.firstWhereOrNull((e) => e.uuid == uuid);
  }

  Structure createStructure({String? title, String? description, TimePeriod? timePeriod, Pen pen = Pen.building}) {
    var structure = Structure(
      title: title,
      description: description,
      timePeriod: timePeriod,
      pen: pen,
    );
    structures.add(structure);
    historyManager.record(AddStructureHistoryEntry(structure));
    return structure;
  }

  void removeStructure(Structure structure) {
    final idx = structures.remove(structure);
    if (idx == null) {
      throw ArgumentError("Structure not found");
    }
    historyManager.record(RemoveStructureHistoryEntry(structure, idx));
  }

  Structure? getStructure(String uuid) {
    return structures.structures.firstWhereOrNull((e) => e.uuid == uuid);
  }

  @override
  void markClean() {
    _extraNeedsSave = false;
    references.markClean();
    structures.markClean();
    historyManager.markClean();
  }

  @override
  void markDirty() {
    _extraNeedsSave = true;
  }

  @override
  bool get needsSave =>
      _extraNeedsSave ||
      historyManager.needsSave ||
      references.needsSave ||
      structures.needsSave;

  @override
  String toString() {
    return "Project(${root.path}${needsSave ? " *" : ""})";
  }

  static Project of(BuildContext context, {bool listen = true}) {
    return Provider.of<Project>(context, listen: listen);
  }
}