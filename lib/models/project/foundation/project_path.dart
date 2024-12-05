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

import 'dart:io';

class ProjectPath {
  final Directory _projectRoot;
  final String _path;

  String get path => _path;

  ProjectPath({required Directory projectRoot, required String path})
      : _projectRoot = projectRoot,
        _path = path {
    if (path.startsWith("/")) {
      throw ArgumentError("Path must be relative");
    }
  }

  factory ProjectPath._fromParts({required Directory projectRoot, required List<String> parts}) {
    return ProjectPath(projectRoot: projectRoot, path: parts.join("/"));
  }

  ProjectPath resolve(String path) {
    // ensure `/` separator
    // ensure path is relative
    if (path.startsWith("/")) {
      throw ArgumentError("Path must be relative");
    }
    List<String> myParts = _path.split("/");
    List<String> parts = path.split("/");

    return ProjectPath._fromParts(projectRoot: _projectRoot, parts: myParts + parts);
  }

  @override
  String toString() {
    return "ProjectPath($_projectRoot : $_path)";
  }

  Directory toDirectory() {
    return Directory("${_projectRoot.path}/$_path");
  }

  File toFile() {
    return File("${_projectRoot.path}/$_path");
  }
}