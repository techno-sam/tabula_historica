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

import '../../extensions/directory.dart';
import 'loading_context.dart';
import 'foundation/project_path.dart';
import 'reference.dart';

class Project {
  final Directory root;
  final List<Reference> _references;

  Iterable<Reference> get references => _references;

  Project({required this.root, List<Reference>? references}): _references = references ?? [];

  factory Project.load(Directory root) {
    File file = File("${root.path}/project.json");
    if (!file.existsSync()) {
      return Project(root: root);
    }

    return Project.fromJson(root, jsonDecode(file.readAsStringSync()));
  }

  factory Project.fromJson(Directory root, Map<String, dynamic> json) {
    LoadingContext ctx = LoadingContext(projectRoot: root);

    return Project(
      root: root,
      references: (json["references"] as List).map((e) => Reference.fromJson(ctx, e)).toList()
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "references": _references.map((e) => e.toJson()).toList()
    };
  }

  Future<void> save() async {
    File file = File("${root.path}/project.json");
    await file.writeAsString(jsonEncode(toJson()));
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
    _references.add(reference);

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
    _references.add(reference);

    return reference;
  }

  Future<void> removeReference(Reference reference) async {
    if (!_references.remove(reference)) {
      throw ArgumentError("Reference not found");
    }
    await reference.image.toFile().delete();
  }

  void removeReferenceSync(Reference reference) {
    if (!_references.remove(reference)) {
      throw ArgumentError("Reference not found");
    }
    reference.image.toFile().deleteSync();
  }
}