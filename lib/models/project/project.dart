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

class ReferenceList extends ChangeNotifier implements NeedsSave {
  final List<Reference> _references;
  bool _extraNeedsSave = false;

  ReferenceList([List<Reference>? references]): _references = references ?? [];

  Iterable<Reference> get references => _references;
  Iterable<Reference> get referencesReversed => _references.reversed;

  get length => _references.length;

  Reference operator[](int index) => _references[index];

  void add(Reference reference, {int? index}) {
    _references.insert(index ?? 0, reference);
    markDirty();
    notifyListeners();
  }

  int? remove(Reference reference) {
    int? idx = _references.nullableIndexOf(reference);
    if (idx != null) {
      _references.removeAt(idx);
      markDirty();
      notifyListeners();
    }
    return idx;
  }

  void reorder(HistoryManager history, int from, int to, {bool skipHistory = false, String? uuid}) {
    if (from < 0 || from >= _references.length) {
      throw ArgumentError.value(from, "from", "invalid index");
    }
    if (to < 0) {
      throw ArgumentError.value(to, "to", "invalid index");
    }
    to = min(to, _references.length);

    if (from == to) {
      return;
    }

    final value = _references.removeAt(from);
    if (uuid != null && value.uuid != uuid) {
      _references.insert(from, value);
      throw ArgumentError.value(uuid, "uuid", "UUID mismatch, got ${value.uuid}");
    }
    final int actualTo = to;
    if (from < to - 1) { // account for the fact that we just shifted every item
      to--;
    }
    _references.insert(to, value);

    if (!skipHistory) {
      history.record(ReorderReferenceHistoryEntry(value.uuid, from, actualTo));
    }

    markDirty();
    notifyListeners();
  }

  @override
  void markClean() {
    _extraNeedsSave = false;
    for (var e in _references) {
      e.markClean();
    }
  }

  @override
  void markDirty() {
    _extraNeedsSave = true;
  }

  @override
  bool get needsSave => _extraNeedsSave || _references.any((e) => e.needsSave);

  @override
  void dispose() {
    for (var e in _references) {
      e.dispose();
    }
    super.dispose();
  }

  static ReferenceList of(BuildContext context, {bool listen = true}) {
    return Provider.of(context, listen: listen);
  }
}

class Project implements NeedsSave {
  final Directory root;
  final ReferenceList references;
  late final HistoryManager historyManager;
  bool _extraNeedsSave = false;

  LoadingContext get loadingContext => LoadingContext(projectRoot: root, getProject: () => this);

  Project._({
    required this.root,
    List<Reference>? references,
    HistoryManager? historyManager
  }): references = ReferenceList(references) {
    this.historyManager = historyManager ?? HistoryManager(getProject: () => this);
  }

  factory Project.load(Directory root) {
    logger.d("Loading project from $root");
    File file = File("${root.path}/project.json");
    if (!file.existsSync()) {
      return Project._(root: root);
    }

    return Project._fromJson(root, jsonDecode(file.readAsStringSync()));
  }

  factory Project._fromJson(Directory root, Map<String, dynamic> json) {
    final tmp = <Project?>[null];
    LoadingContext ctx = LoadingContext(
      getProject: () => tmp[0]!,
      projectRoot: root,
    );

    final project = Project._(
      root: root,
      references: json.mapSingle("references", (refs) => (refs as List).map((e) => Reference.fromJson(ctx, e)).toList()),
      historyManager: json.mapSingle("historyManager", (hm) => HistoryManager.fromJson(ctx, hm))
    );
    tmp[0] = project;
    return project;
  }

  Map<String, dynamic> toJson() {
    return {
      "references": references.references.map((e) => e.toJson()).toList(),
      "historyManager": historyManager.toJson()
    };
  }

  void dispose() {
    references.dispose();
    historyManager.dispose();
    logger.d("Disposed $this");
  }

  static const JsonEncoder _prettyEncoder = JsonEncoder.withIndent("  ");

  Future<void> save() async {
    File file = File("${root.path}/project.json");
    await file.writeAsString(_prettyEncoder.convert(toJson()));
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

  @override
  void markClean() {
    _extraNeedsSave = false;
    references.markClean();
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
      references.needsSave;

  @override
  String toString() {
    return "Project(${root.path}${needsSave ? " *" : ""})";
  }

  static Project of(BuildContext context, {bool listen = true}) {
    return Provider.of<Project>(context, listen: listen);
  }
}