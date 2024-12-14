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

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../extensions/iterables.dart';
import '../../extensions/directory.dart';
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

  void add(Reference reference) {
    _references.add(reference);
    markDirty();
    notifyListeners();
  }

  bool remove(Reference reference) {
    var found = _references.remove(reference);
    if (found) {
      markDirty();
      notifyListeners();
    }
    return found;
  }

  void reorder(HistoryManager history, int from, int to) {
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

    // todo add history

    final value = _references.removeAt(from);
    if (from < to) { // account for the fact that we just shifted every item
      to--;
    }
    _references.insert(to, value);

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

  static ReferenceList of(BuildContext context, {bool listen = true}) {
    return Provider.of(context, listen: listen);
  }
}

class Project implements NeedsSave {
  final Directory root;
  final ReferenceList references;
  final HistoryManager historyManager;
  bool _extraNeedsSave = false;

  Project._({
    required this.root,
    List<Reference>? references,
    HistoryManager? historyManager
  }): references = ReferenceList(references), historyManager = historyManager ?? HistoryManager();

  factory Project.load(Directory root) {
    File file = File("${root.path}/project.json");
    if (!file.existsSync()) {
      return Project._(root: root);
    }

    return Project._fromJson(root, jsonDecode(file.readAsStringSync()));
  }

  factory Project._fromJson(Directory root, Map<String, dynamic> json) {
    LoadingContext ctx = LoadingContext(projectRoot: root);

    return Project._(
      root: root,
      references: json.mapSingle("references", (refs) => (refs as List).map((e) => Reference.fromJson(ctx, e)).toList()),
      historyManager: json.mapSingle("historyManager", (hm) => HistoryManager.fromJson(hm))
    );
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
  }

  static const JsonEncoder _prettyEncoder = JsonEncoder.withIndent("  ");

  Future<void> save() async {
    File file = File("${root.path}/project.json");
    await file.writeAsString(_prettyEncoder.convert(toJson()));
    markClean();
  }

  Future<Reference> createReference(File sourceImage, Point<int> dimensions, String? title) async {
    String name = sourceImage.path.split("/").last;
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

    return reference;
  }

  Reference createReferenceSync(File sourceImage, Point<int> dimensions, String? title) {
    String name = sourceImage.path.split("/").last;
    Directory $references = root.resolve("references");
    $references.createSync(recursive: true);

    File destImage = $references.resolveFile(name);
    sourceImage.copySync(destImage.path);

    var reference = Reference(
      image: ProjectPath(projectRoot: root, path: "references/$name"),
      imageDimensions: dimensions,
      title: title
    );
    references.add(reference);

    return reference;
  }

  Future<void> removeReference(Reference reference) async {
    if (!references.remove(reference)) {
      throw ArgumentError("Reference not found");
    }
    await reference.image.toFile().delete();
  }

  void removeReferenceSync(Reference reference) {
    if (!references.remove(reference)) {
      throw ArgumentError("Reference not found");
    }
    reference.image.toFile().deleteSync();
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

  static Project of(BuildContext context, {bool listen = true}) {
    return Provider.of<Project>(context, listen: listen);
  }
}